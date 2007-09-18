# FiscalYearlyArchives
#
# $Id$
#
# This software is provided as-is. You may use it for commercial or 
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2007 Hirotaka Ogawa

package MT::Plugin::FiscalYearlyArchives;
use strict;
use base qw(MT::Plugin);

use MT;
use MT::Entry;

our $VERSION = '0.03';

my $plugin = __PACKAGE__->new({
    id => 'fiscal_yearly_archives',
    name => 'FiscalYearlyArchives',
    description => q(<MT_TRANS phrase="A plugin for building Fiscal Yearly Archives">),
    doc_link => 'http://code.as-is.net/wiki/FiscalYearlyArchives',
    author_name => 'Hirotaka Ogawa',
    author_link => 'http://profile.typekey.com/ogawa/',
    version => $VERSION,
    l10n_class => 'FiscalYearlyArchives::L10N',
    system_config_template => 'system_config.tmpl',
    settings => new MT::PluginSettings([
	['fiscal_start_month', { Default => 4, Scope => 'system' }],
    ]),
});
MT->add_plugin($plugin);

use MT::WeblogPublisher;
sub init_registry {
    my $plugin = shift;
    $plugin->registry({
	tags => {
	    function => {
		ArchiveFiscalYear => \&archive_fiscal_year,
	    },
	},
	'archive_types' => {
	    'FiscalYearly' =>
		ArchiveType(
		    name => 'FiscalYearly',
		    archive_label => \&archive_label,
		    archive_file => \&archive_file,
		    archive_title => \&archive_title,
		    date_range => \&date_range,
		    archive_group_iter => \&archive_group_iter,
		    archive_group_entries => \&archive_group_entries,
		    archive_entries_count => \&archive_entries_count,
		    default_archive_templates => [
			ArchiveFileTemplate(
			    label => 'fiscal/yyyy/index.html',
			    template => 'fiscal/<$MTArchiveFiscalYear$>/%i',
			    default => 1
			),
		    ],
		    dynamic_template => 'fiscal/<$MTArchiveFiscalYear$>',
		    dynamic_support => 1,
		    date_based => 1,
		    # ??? i don't know what it really means ???
		    template_params => {
			datebased_only_archive => 1,
			datebased_fiscal_yearly_archive => 1,
			module_fiscal_yearly_archives => 1,
			main_template => 1,
			archive_template => 1,
			archive_class => "datebased-fiscal-yearly-archive",
		    },
		),
	}
    });
}

# a dirty hack to avoid multiple get_config_value() calls for
# optimization
{
    my $start_month;

    # fetch 'fiscal_start_month' at the first time the method is
    # called, and cache it to $start_month
    sub fiscal_start_month {
	return $start_month if $start_month;
	$start_month = $plugin->get_config_value('fiscal_start_month') || 4;
    }

    # invalidate $start_month cache everytime init_request() called
    sub init_request {
	my $plugin = shift;
	$plugin->SUPER::init_request(@_);
	$start_month = undef;
    }
}

sub ts2fiscal {
    my ($ts) = @_;
    my ($y, $m) = unpack('A4A2', $ts);
    my $start_month = fiscal_start_month();
    $y-- if $m < $start_month;
    $y;
}

# MTArchiveFiscalYear tag
sub archive_fiscal_year {
    my ($ctx, %param) = @_;
    my $ts = $ctx->{current_timestamp};
    my $tag = $ctx->stash('tag');
    return $ctx->error(MT->translate("You used an [_1] tag without a date context set up.", "MT$tag"))
	unless defined $ts;
    ts2fiscal($ts);
}

sub start_end_fiscal_year {
    my ($ts) = @_;
    my ($start_year, $start_month) = (ts2fiscal($ts), fiscal_start_month());
    my $start = sprintf("%04d%02d%02d000000", $start_year, $start_month, 1);
    return $start unless wantarray;

    my ($end_year, $end_month, $end_day);
    if ($start_month == 1) {
	($end_year, $end_month, $end_day) = ($start_year, 12, 31);
    } else {
	($end_year, $end_month) = ($start_year + 1, $start_month - 1);
	$end_day = MT::Util::days_in($end_month, $end_year);
    }
    my $end = sprintf("%04d%02d%02d235959", $end_year, $end_month, $end_day);
    ($start, $end);
}

sub archive_label {
    $plugin->translate('FISCAL-YEARLY_ADV');
}

sub archive_file {
    my ($ctx, %param) = @_;
    my $timestamp = $param{Timestamp};
    my $file_tmpl = $param{Template};
    my $blog = $ctx->{__stash}{blog};

    my $file;
    if ($file_tmpl) {
	($ctx->{current_timestamp}, $ctx->{current_timestamp_end}) =
	    start_end_fiscal_year($timestamp);
    } else {
	my $year = ts2fiscal($timestamp);
	$file = sprintf("04d/index", $year);
    }
    $file;
}

sub archive_title {
    my ($ctx, $entry_or_ts) = @_;
    my $ts = ref $entry_or_ts ? $entry_or_ts->authored_on : $entry_or_ts;
    my $year = ts2fiscal($ts);
    my $lang = lc MT->current_language || 'en_us';
    $lang = 'ja' if lc($lang) eq 'jp';
    $lang eq 'ja' ? $year . '&#24180;&#24230;' : $year;
}

sub date_range { start_end_fiscal_year(@_) }

sub archive_group_iter {
    my ($ctx, $args) = @_;
    my $blog = $ctx->stash('blog');

    my $sort_order = ($args->{sort_order} || '') eq 'ascend' ? 'ascend' : 'descend';
    my $order = $sort_order eq 'ascend' ? 'asc' : 'desc';

    my $iter = MT->model('entry')->count_group_by({
	blog_id => $blog->id,
	status  => MT::Entry::RELEASE(),
    }, {
	group => ["extract(year from authored_on)", "extract(month from authored_on)"],
	sort => "extract(year from authored_on) $order, extract(month from authored_on) $order",
    })
	or return $ctx->error("Couldn't get FiscalYearly archive list");

    # dirrty!
    my @count_groups;
    my $prev_year;
    while (my @row = $iter->()) {
	my $ts = sprintf("%04d%02d%02d000000", $row[1], $row[2], 1);
	my ($start, $end) = start_end_fiscal_year($ts);
	my $year = ts2fiscal($ts);
	if (defined $prev_year && $prev_year == $year) {
	    $count_groups[-1]->{count} += $row[0];
	} else {
	    push @count_groups, {
		count => $row[0],
		fiscal_year => $year,
		start => $start,
		end => $end,
	    };
	    $prev_year = $year;
	}
    }
    my $lastn = $args->{lastn};
    splice(@count_groups, $lastn) if $lastn;

    return sub {
	while (my $group = shift(@count_groups)) {
	    return ($group->{count}, %$group);
	}
	undef;
    };
}

sub archive_group_entries {
    my ($ctx, %param) = @_;
    my $ts = sprintf("%04d%02d%02d000000", $param{fiscal_year}, fiscal_start_month(), 1)
	if %param;
    my ($start, $end);
    if ($ts) {
	($start, $end) = start_end_fiscal_year($ts);
	$ctx->{current_timestamp}     = $start;
	$ctx->{current_timestamp_end} = $end;
    } else {
	$start = $ctx->{current_timestamp};
	$end   = $ctx->{current_timestamp_end};
    }
    my $blog = $ctx->stash('blog');
    my @entries = MT->model('entry')->load({
	blog_id     => $blog->id,
	status      => MT::Entry::RELEASE(),
	authored_on => [$start, $end],
    }, {
	range  => { authored_on => 1 },
	'sort' => 'authored_on',
	'direction' => 'descend',
    })
	or return $ctx->error("Couldn't get FiscalYearly archive list");
    \@entries;
}

sub archive_entries_count {
    my ($blog, $at, $entry) = @_;
    my $ts = $entry->authored_on;
    my ($start, $end) = start_end_fiscal_year($ts)
	if $ts;
    my $count = MT->model('entry')->count({
	blog_id => $blog->id,
	status  => MT::Entry::RELEASE(),
	$ts   ? (authored_on => [$start, $end]) : (),
    }, {
	$ts   ? (range => { authored_on => 1 }) : (),
    });
    $count;
}

1;

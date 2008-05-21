# $Id$
package FiscalYearlyArchives::FiscalYearly;
use strict;
use base qw( MT::ArchiveType::Date );

use FiscalYearlyArchives::Util qw( fiscal_start_month ts2fiscal start_end_fiscal_year );

sub name {
    return 'FiscalYearly';
}

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('FISCAL-YEARLY_ADV');
}

sub default_archive_templates {
    return [
        {
            label    => 'fiscal/yyyy/index.html',
            template => 'fiscal/<$MTArchiveFiscalYear$>/%i',
            default  => 1,
        },
    ];
}

sub dynamic_template {
    return 'archives/fiscal/<$MTArchiveFiscalYear$>';
}

sub template_params {
    return {
        archive_class                   => "datebased-fiscal-yearly-archive",
        datebased_only_archive          => 1,
        datebased_fiscal_yearly_archive => 1,
        archive_template                => 1,
        archive_listing                 => 1,
    };
}

sub archive_title {
    my $obj = shift;
    my ( $ctx, $entry_or_ts ) = @_;
    my $ts = ref $entry_or_ts ? $entry_or_ts->authored_on : $entry_or_ts;
    my $year = ts2fiscal($ts);
    my $lang = lc MT->current_language || 'en_us';
    $lang = 'ja' if lc($lang) eq 'jp';

    sprintf( "%s%s", $year, ( $lang eq 'ja' ? '&#24180;&#24230;' : '' ) );
}

sub archive_file {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp = $param{Timestamp};
    my $file_tmpl = $param{Template};
    my $blog      = $ctx->{__stash}{blog};

    my $file;
    if ($file_tmpl) {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ) =
          start_end_fiscal_year($timestamp);
    } else {
        my $year = ts2fiscal($timestamp);
        $file = sprintf("%04d/index", $year);
    }
    $file;
}

sub date_range {
    my $obj = shift;
    start_end_fiscal_year(@_);
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog   = $ctx->stash('blog');
    my $sort_order = ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;

    require MT::Entry;
    my $iter = MT::Entry->count_group_by(
        {
            blog_id => $blog->id,
            status  => MT::Entry::RELEASE(),
        },
        {
            group => ["extract(year from authored_on)", "extract(month from authored_on)"],
            sort  => "extract(year from authored_on) $order, extract(month from authored_on) $order",
        }
    ) or return $ctx->error("Couldn't get " . $obj->name . " archive list");

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
                count       => $row[0],
                fiscal_year => $year,
                start       => $start,
                end         => $end,
            };
            $prev_year = $year;
        }
    }
    splice(@count_groups, $limit) if $limit;

    return sub {
        while (my $group = shift(@count_groups)) {
            return ($group->{count}, %$group);
        }
        undef;
    };
}

sub archive_group_entries {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $ts =
        $param{fiscal_year}
    ? sprintf("%04d%02d%02d000000", $param{fiscal_year}, fiscal_start_month(), 1)
        : undef;
    my $limit = $param{limit};
    $obj->dated_group_entries( $ctx, 'FiscalYearly', $ts, $limit );
}

sub archive_entries_count {
    my $obj = shift;
    my ( $blog, $at, $entry ) = @_;
    return $obj->SUPER::archive_entries_count(
        {
            Blog        => $blog,
            ArchiveType => $at,
            Timestamp   => $entry->authored_on
        }
    );
}

1;

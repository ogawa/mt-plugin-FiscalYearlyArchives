# $Id$
package FiscalYearlyArchives::CategoryFiscalYearly;
use strict;
use base qw( MT::ArchiveType::Category FiscalYearlyArchives::FiscalYearly );

use FiscalYearlyArchives::Util qw( fiscal_start_month ts2fiscal start_end_fiscal_year );
use MT::Util qw( dirify );

sub name {
    return 'Category-FiscalYearly';
}

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('CATEGORY-FISCAL-YEARLY_ADV');
}

sub default_archive_templates {
    return [
        {
            label    => 'category/sub-category/fiscal/yyyy/index.html',
            template => '%-c/fiscal/<$MTArchiveFiscalYear$>/%i',
            default  => 1,
        },
        {
            label    => 'category/sub_category/fiscal/yyyy/index.html',
            template => '%c/fiscal/<$MTArchiveFiscalYear$>/%i',
        },
    ];
}

sub dynamic_template {
    return 'category/<$MTCategoryID$>/fiscal/<$MTArchiveFiscalYear$>';
}

sub template_params {
    return {
        archive_class                   => "category-fiscal-yearly-archive",
        category_fiscal_yearly_archive  => 1,
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
    my $cat = $obj->display_name($ctx);

    sprintf( "%s%s%s", $cat, $year, ( $lang eq 'ja' ? '&#24180;&#24230;' : '' ) );
}

sub archive_file {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp = $param{Timestamp};
    my $file_tmpl = $param{Template};
    my $blog      = $ctx->{__stash}{blog};
    my $cat       = $ctx->{__stash}{cat} || $ctx->{__stash}{category};
    my $entry     = $ctx->{__stash}{entry};
    my $file;

    my $this_cat = $cat ? $cat : ( $entry ? $entry->category : undef );
    if ($file_tmpl) {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ) =
            start_end_fiscal_year( $timestamp );
        $ctx->stash( 'archive_category', $this_cat );
        $ctx->{inside_mt_categories} = 1;
        $ctx->{__stash}{category} = $this_cat;
    }
    else {
        if ( !$this_cat ) {
            return "";
        }
        my $label = '';
        $label = dirify( $this_cat->label );
        if ( $label !~ /\w/ ) {
            $label = $this_cat ? "cat" . $this_cat->id : "";
        }
        my $year = ts2fiscal($timestamp);
        $file = sprintf( "%s/%04d/index", $this_cat->category_path, $year );
    }
    $file;
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog   = $ctx->stash('blog');
    my $cat    = $ctx->stash('archive_category') || $ctx->stash('category');
    my $sort_order = ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $cat_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;

    my $cat_iter;
    if ($cat) {
        my @cats = ( $cat );
        $cat_iter = sub { shift @cats };
    } else {
        require MT::Category;
        $cat_iter = MT::Category->load_iter(
            {
                blog_id   => $blog->id,
            },
            {
                sort      => 'label',
                direction => $cat_order,
            }
        );
    }

    my @count_groups;
    require MT::Entry;
    require MT::Placement;
    while (my $c = $cat_iter->()) {
        my $iter = MT::Entry->count_group_by(
            {
                blog_id => $blog->id,
                status  => MT::Entry::RELEASE(),
            },
            {
                group => ["extract(year from authored_on)", "extract(month from authored_on)"],
                sort  => "extract(year from authored_on) $order, extract(month from authored_on) $order",
                join  => [ 'MT::Placement', 'entry_id', { category_id => $c->id } ],
            }
        ) or return $ctx->error("Couldn't get " . $obj->name . " archive list");

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
                    category    => $c,
                };
                $prev_year = $year;
            }
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
    ? sprintf( "%04d%02d%02d000000", $param{fiscal_year}, fiscal_start_month(), 1 )
        : $ctx->stash('current_timestamp');
    my $cat = $param{category} || $ctx->stash('archive_category');
    my $limit = $param{limit};
    $obj->dated_category_entries( $ctx, 'Category-FiscalYearly', $cat, $ts, $limit );
}

sub archive_entries_count {
    my $obj = shift;
    my ( $blog, $at, $entry ) = @_;
    my $cat = $entry->category;
    return 0 unless $cat;
    return $obj->SUPER::archive_entries_count(
        {
            Blog        => $blog,
            ArchiveType => $at,
            Timestamp   => $entry->authored_on,
            Category    => $cat
        }
    );
}

*date_range             = \&FiscalYearlyArchives::FiscalYearly::date_range;
*next_archive_entry     = \&MT::ArchiveType::Date::next_archive_entry;
*previous_archive_entry = \&MT::ArchiveType::Date::previous_archive_entry;

1;

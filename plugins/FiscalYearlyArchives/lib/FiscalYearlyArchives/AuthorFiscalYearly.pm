# $Id$
package FiscalYearlyArchives::AuthorFiscalYearly;
use strict;
use base qw( MT::ArchiveType::Author FiscalYearlyArchives::FiscalYearly );

use FiscalYearlyArchives::Util
  qw( fiscal_start_month ts2fiscal start_end_fiscal_year );
use MT::Util qw( dirify );

sub name {
    return 'Author-FiscalYearly';
}

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('AUTHOR-FISCAL-YEARLY_ADV');
}

sub default_archive_templates {
    return [
        {
            label    => 'author/author-display-name/fiscal/yyyy/index.html',
            template => 'author/%-a/fiscal/<$MTArchiveFiscalYear$>/%f',
            default  => 1,
        },
        {
            label    => 'author/author_display_name/fiscal/yyyy/index.html',
            template => 'author/%a/fiscal/<$MTArchiveFiscalYear$>/%f',
        },
    ];
}

sub dynamic_template {
    return 'author/<$MTEntryAuthorID$>/fiscal/<$MTArchiveFiscalYear$>';
}

sub template_params {
    return {
        archive_class                => "author-fiscal-yearly-archive",
        author_fiscal_yearly_archive => 1,
        archive_template             => 1,
        archive_listing              => 1,
    };
}

sub archive_title {
    my $obj = shift;
    my ( $ctx, $entry_or_ts ) = @_;
    my $ts   = ref $entry_or_ts ? $entry_or_ts->authored_on : $entry_or_ts;
    my $year = ts2fiscal($ts);
    my $lang = lc MT->current_language || 'en_us';
    $lang = 'ja' if lc($lang) eq 'jp';
    my $author = $obj->display_name($ctx);

    sprintf( "%s%s%s",
        $author, $year, ( $lang eq 'ja' ? '&#24180;&#24230;' : '' ) );
}

sub archive_file {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp = $param{Timestamp};
    my $file_tmpl = $param{Template};
    my $author    = $ctx->{__stash}{author};
    my $entry     = $ctx->{__stash}{entry};
    my $file;
    my $this_author = $author ? $author : ( $entry ? $entry->author : undef );
    return "" unless $this_author;
    my $name = dirify( $this_author->nickname );

    if ( $name eq '' || !$file_tmpl ) {
        $name = 'author' . $this_author->id if $name !~ /\w/;
        my $year = ts2fiscal($timestamp);
        $file = sprintf( "%s/%04d/index", $name, $year );
    }
    else {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ) =
          start_end_fiscal_year($timestamp);
    }
    $file;
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog   = $ctx->stash('blog');
    my $author = $ctx->stash('author');
    my $sort_order =
      ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $auth_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;

    require MT::Entry;
    my $auth_iter;
    if ($author) {
        my @authors = ($author);
        $auth_iter = sub { shift @authors };
    }
    else {
        require MT::Author;
        $auth_iter = MT::Author->load_iter(
            undef,
            {
                sort      => 'name',
                direction => $auth_order,
                join      => [
                    'MT::Entry', 'author_id',
                    { status => MT::Entry::RELEASE(), blog_id => $blog->id },
                    { unique => 1 },
                ],
            }
        );
    }

    my @count_groups;
    while ( my $auth = $auth_iter->() ) {
        my $iter = MT::Entry->count_group_by(
            {
                blog_id   => $blog->id,
                status    => MT::Entry::RELEASE(),
                author_id => $auth->id,
            },
            {
                group => [
                    "extract(year from authored_on)",
                    "extract(month from authored_on)"
                ],
                sort =>
"extract(year from authored_on) $order, extract(month from authored_on) $order",
            }
          )
          or
          return $ctx->error( "Couldn't get " . $obj->name . " archive list" );

        my $prev_year;
        while ( my @row = $iter->() ) {
            my $ts = sprintf( "%04d%02d%02d000000", $row[1], $row[2], 1 );
            my ( $start, $end ) = start_end_fiscal_year($ts);
            my $year = ts2fiscal($ts);
            if ( defined $prev_year && $prev_year == $year ) {
                $count_groups[-1]->{count} += $row[0];
            }
            else {
                push @count_groups,
                  {
                    count       => $row[0],
                    fiscal_year => $year,
                    start       => $start,
                    end         => $end,
                    author      => $auth,
                  };
                $prev_year = $year;
            }
        }
    }
    splice( @count_groups, $limit ) if $limit;

    return sub {
        while ( my $group = shift(@count_groups) ) {
            return ( $group->{count}, %$group );
        }
        undef;
    };
}

sub archive_group_entries {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $ts =
      $param{fiscal_year}
      ? sprintf( "%04d%02d%02d000000",
        $param{fiscal_year}, fiscal_start_month(), 1 )
      : $ctx->stash('current_timestamp');
    my $author = $param{author} || $ctx->stash('author');
    my $limit = $param{limit};
    $obj->dated_author_entries( $ctx, 'Author-FiscalYearly', $author, $ts,
        $limit );
}

sub archive_entries_count {
    my $obj = shift;
    my ( $blog, $at, $entry ) = @_;
    my $auth = $entry->author;
    return $obj->SUPER::archive_entries_count(
        {
            Blog        => $blog,
            ArchiveType => $at,
            Timestamp   => $entry->authored_on,
            Author      => $auth
        }
    );
}

*date_range             = \&FiscalYearlyArchives::FiscalYearly::date_range;
*next_archive_entry     = \&MT::ArchiveType::Date::next_archive_entry;
*previous_archive_entry = \&MT::ArchiveType::Date::previous_archive_entry;

1;

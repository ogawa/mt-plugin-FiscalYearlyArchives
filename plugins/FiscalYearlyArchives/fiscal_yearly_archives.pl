# FiscalYearlyArchives
#
# $Id$
#
# This software is provided as-is. You may use it for commercial or
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2007-2008 Hirotaka Ogawa

package MT::Plugin::FiscalYearlyArchives;
use strict;
use base qw( MT::Plugin );

use MT;

our $VERSION = '0.10';

my $plugin = __PACKAGE__->new(
    {
        id   => 'fiscal_yearly_archives',
        name => 'FiscalYearlyArchives',
        description =>
          q(<MT_TRANS phrase="A plugin for building Fiscal Yearly Archives">),
        doc_link => 'https://github.com/ogawa/mt-plugin-FiscalYearlyArchives',
        author_name            => 'Hirotaka Ogawa',
        author_link            => 'https://github.com/ogawa',
        version                => $VERSION,
        l10n_class             => 'FiscalYearlyArchives::L10N',
        system_config_template => 'system_config.tmpl',
        settings               => new MT::PluginSettings(
            [ [ 'fiscal_start_month', { Default => 4, Scope => 'system' } ], ]
        ),
    }
);
MT->add_plugin($plugin);

sub instance { $plugin }

sub init_registry {
    my $plugin = shift;
    $plugin->registry(
        {
            tags =>
              { function => { ArchiveFiscalYear => \&archive_fiscal_year, }, },
            archive_types => {
                'FiscalYearly' => 'FiscalYearlyArchives::FiscalYearly',
                'Author-FiscalYearly' =>
                  'FiscalYearlyArchives::AuthorFiscalYearly',
                'Category-FiscalYearly' =>
                  'FiscalYearlyArchives::CategoryFiscalYearly',
            },
        }
    );
}

# MTArchiveFiscalYear tag
use FiscalYearlyArchives::Util qw( ts2fiscal );

sub archive_fiscal_year {
    my ( $ctx, %param ) = @_;
    my $ts  = $ctx->{current_timestamp};
    my $tag = $ctx->stash('tag');
    return $ctx->error(
        MT->translate(
            "You used an [_1] tag without a date context set up.", "MT$tag"
        )
    ) unless defined $ts;
    ts2fiscal($ts);
}

1;

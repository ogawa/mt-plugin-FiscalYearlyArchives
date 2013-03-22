# $Id$
package FiscalYearlyArchives::Util;
use strict;
use base qw( Exporter );

our @EXPORT_OK = qw( fiscal_start_month ts2fiscal start_end_fiscal_year );

sub fiscal_start_month {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->get_config_value('fiscal_start_month') || 4;
}

sub ts2fiscal {
    my ($ts) = @_;
    my ( $y, $m ) = unpack( 'A4A2', $ts );
    my $start_month = fiscal_start_month();
    $y-- if $m < $start_month;
    $y;
}

sub start_end_fiscal_year {
    my ($ts) = @_;
    my ( $start_year, $start_month ) = ( ts2fiscal($ts), fiscal_start_month() );
    my $start = sprintf( "%04d%02d%02d000000", $start_year, $start_month, 1 );
    return $start unless wantarray;

    my ( $end_year, $end_month, $end_day );
    if ( $start_month == 1 ) {
        ( $end_year, $end_month, $end_day ) = ( $start_year, 12, 31 );
    }
    else {
        ( $end_year, $end_month ) = ( $start_year + 1, $start_month - 1 );
        require MT::Util;
        $end_day = MT::Util::days_in( $end_month, $end_year );
    }
    my $end = sprintf( "%04d%02d%02d235959", $end_year, $end_month, $end_day );
    ( $start, $end );
}

1;

<?php
function smarty_function_mtarchivefiscalyear($args, &$ctx) {
    $ts = $ctx->stash('current_timestamp');
    if ($ts) {
        $y = substr($ts, 0, 4);
        $m = substr($ts, 4, 2);
	$start_month = fiscal_start_month($ctx);
	if ($m < $start_month) {
	    $y--;
	}
	return $y;
    } else {
	$tag = $ctx->stash('tag');
	return $ctx->error("You used an mt$tag tag without a date context set up.");
    }
}

function fiscal_start_month($ctx) {
    $start_month = $ctx->stash('fiscal_start_month');
    if ($start_month)
	return $start_month;
    $config = $ctx->mt->db->fetch_plugin_data('FiscalYearlyArchives', 'system');
    $start_month = isset($config['fiscal_month_start']) ? $config['fiscal_month_start'] : 4;
    $ctx->stash('fiscal_start_month', $start_month);
    return $start_month;
}
?>

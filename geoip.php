<?php

$ip_address = $_SERVER['REMOTE_ADDR'];
echo"ip_address, ";
$ip_country = geoip_country_code_by_name ($ip_address);
echo"ip_country";

?>

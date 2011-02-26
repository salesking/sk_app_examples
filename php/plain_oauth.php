<?php
    $app_id = "7e5e7b099299309c";
    $app_secret = "fa5b25c6193bcfc88f1925929cdef972";
    $app_url = "http://localhost/oauth_test";
    $app_scope = "api/clients:read";
    $sk_url = "http://demo.salesking.local:3000";

  $app_id = "APP_CLIENT_ID";
  $app_secret = "APP_SECRET";
  $app_url = "http://localhost/oauth_test";
  $app_scope = "api/clients:read";
  $sk_url = "https://SUBDOMAIN.salesking.eu";

  $code = $_REQUEST["code"];

  if(empty($code)) { # redirect to authorize url
    $dialog_url = $sk_url . "/oauth/authorize?" .
                "client_id=". $app_id .
                "&scope=" . urlencode($app_scope);
                "&redirect_uri=" . urlencode($app_url);

    echo("<script> top.location.href='" . $dialog_url . "'</script>");
  }
  # build url to get the access token
  $token_url = $sk_url . "/oauth/access_token?" .
              "client_id=". $app_id .
              "&redirect_uri=" . urlencode($app_url) .
              "&client_secret=" . $app_secret .
              "&code=" . $code;
  # GET and parse resonse json
  $resp = json_decode(file_get_contents($token_url));
  # build url
  $usr_url = $sk_url . "/api/users/current?access_token=" . $resp->access_token;
  # GET info about current user
  $user = json_decode(file_get_contents($usr_url));
  echo("King: " . $user->user->email);

?>

 <?php

  $app_id = "APP_CLIENT_ID";
  $app_secret = "APP_SECRET";
  $app_canvas_url = 'http://localhost/oauth_canvas';
  $sk_url = 'https://SUBDOMAIN.salesking.eu';
  $sk_canvas_url = 'https://SUBDOMAIN.salesking.eu/app/CANVAS_PAGE_SLUG';

  # redirect url for auth dialog
  $auth_url = $sk_url . "/oauth/authorize?client_id=" . $app_id .
              "&redirect_uri=" . urlencode($app_canvas_url);

  $signed_request = $_REQUEST["signed_request"];
  list($encoded_sig, $payload) = explode('.', $signed_request, 2);
  $data = json_decode(base64_decode(strtr($payload, '-_', '+/')), true);

  # the callback from authorize, has the code needed to grab the
  # access_token and allow the app.
  # This part can be kicked if the user already allowed the app
  $code = $_REQUEST["code"];
  if(!empty($code)) { # authorize app .. not using access_token later on
    $token_url = $sk_url . "/oauth/access_token?" .
      "client_id=". $app_id .
      "&redirect_uri=" . urlencode($app_canvas_url) .
      "&client_secret=" . $app_secret .
      "&code=" . $code;
    # get token, not saved
    $resp = json_decode(file_get_contents($token_url));
    # redirect to the internal canvas page now showing authenicated status
    echo("<script> top.location.href='" . $sk_canvas_url . "'</script>");
  }

  # first time user comes in redirect him to the oauth dialog
  if (empty($data["user_id"]) && empty($code) )  {
    echo("<script> top.location.href='" . $auth_url . "'</script>");
  } else { # third time the user has allowed the app so we see his user id
    echo ("Welcome User: " . $data["user_id"]);
  }
 ?>

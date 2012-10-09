<%@ Page Language="C#" AutoEventWireup="true"%>
<%@ Import namespace="System.Linq"%>
<%@ Import Namespace="ServiceStack.Text" %>

<script runat="server">

    protected override void OnInit(EventArgs args)
    {
        var client_id = ConfigurationManager.AppSettings["Github.OAuth.Client_id"];
        var client_secret = ConfigurationManager.AppSettings["Github.OAuth.Client_secret"];
        
        var oAuthCode = Request["code"];
        var oAuthState = Request["state"];

        var verifyState = (Session["Github.OAuth.CurrentState"] ?? "").ToString();

        Session.Remove("Github.OAuth.CurrentState");

        // Something is wrong, bail
        if (String.IsNullOrEmpty(oAuthState) 
            || String.IsNullOrEmpty(verifyState)
            || oAuthState != verifyState)
        {
            Response.End();
        }

        const string tokenUrl = "https://github.com/login/oauth/access_token";

        var request = new OAuthTokenRequest
                          {client_id = client_id, client_secret = client_secret, code = oAuthCode, state = verifyState};

        var response = JsonUtil.PostAndGetStringFromUrl(null, tokenUrl, request.ToJson(), "application/json", "application/json").FromJson<OAuthTokenResponse>();

        Session["Github.OAuth.AccessToken"] = response.access_token;

        Response.Redirect("~/");
    }
</script>
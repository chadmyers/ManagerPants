<%@ Page Language="C#" AutoEventWireup="true"%>

<script runat="server">

    protected override void OnInit(EventArgs args)
    {
        var client_id = ConfigurationManager.AppSettings["Github.OAuth.Client_id"];
        
        var verifyState = Guid.NewGuid().ToString();
        Session.Remove("Github.OAuth.CurrentState");
        Session.Add("Github.OAuth.CurrentState", verifyState);

        var url = string.Format("https://github.com/login/oauth/authorize?client_id={0}&scope=repo&state={1}", client_id,
                                verifyState);
        
        Response.Redirect(url);       
    }
</script>
<%@ Page Language="C#" AutoEventWireup="true"%>
<%@Import namespace="System.Linq"%>
<%@ Import Namespace="ServiceStack.Text" %>

<script runat="server">

    protected override void OnInit(EventArgs args)
    {
        var repo = ConfigurationManager.AppSettings["Github.Repo"];
        var access_token = (Session["Github.OAuth.AccessToken"] ?? "").ToString();
        
        if( String.IsNullOrEmpty(access_token))
        {
            Response.Redirect("~/startoauth.aspx");
        }
        
        if (Request.HttpMethod == "POST")
        {
            foreach (var key in Request.Form.AllKeys)
            {
                if (!key.StartsWith("order-"))
                {
                    continue;
                }

                var issueNum = key.Replace("order-", "");

                int newOrder;
                if (!Int32.TryParse(Request.Form[key], out newOrder))
                {
                    continue;
                }

                var issue =
                    JsonUtil.GetAllPagesJson<GithubIssue>(access_token, "repos/" + repo + "/issues/" + issueNum).
                        FirstOrDefault();

                if (issue == null)
                {
                    continue;
                }


                var newMeta = issue.Meta;
                newMeta.Order = newOrder;

                var newBody = JsonUtil.SetMeta(newMeta, issue.Body);

                var bodyReq = new BodyUpdate(newBody, access_token);

                var updatedJson = bodyReq.ToJson();

                var updateUrl = Constants.GithubApiBaseUrl + "repos/" + repo + "/issues/" + issueNum;
                
                JsonUtil.PatchAndGetStringFromUrl(access_token, updateUrl, updatedJson, r => { });

                Cache.Remove(Constants.ISSUE_CACHE_KEY);
            }
        }

        Response.Redirect("~/");
    }
</script>
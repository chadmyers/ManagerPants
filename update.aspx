<%@ Page Language="C#" AutoEventWireup="true"%>
<%@Import namespace="System.Linq"%>
<%@ Import Namespace="ServiceStack.Text" %>

<script runat="server">

    protected override void OnInit(EventArgs args)
    {
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
                    JsonUtil.GetAllPagesJson<GithubIssue>("repos/OWNERNAME/REPONAME/issues/" + issueNum).
                        FirstOrDefault();

                if (issue == null)
                {
                    continue;
                }


                var newMeta = issue.Meta;
                newMeta.Order = newOrder;

                var newBody = JsonUtil.SetMeta(newMeta, issue.Body);

                var bodyReq = new BodyUpdate(newBody, JsonUtil.APITOKEN);

                var updatedJson = bodyReq.ToJson();
                JsonUtil.PatchAndGetStringFromUrl("repos/OWNERNAME/REPONAME/issues/" + issueNum, updatedJson, r => { });
            }
        }

        Response.Redirect("~/");
    }
</script>
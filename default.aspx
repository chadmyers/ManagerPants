<%@ Page Language="C#" AutoEventWireup="true"%>
<%@Import namespace="System.Linq"%>

<script runat="server">

    public bool OrderEntryMode { get; set; }    
    public Dictionary<GithubMilestone, IEnumerable<GithubIssue>> issuesToDisplay;
    public string repo = ConfigurationManager.AppSettings["Github.Repo"];
    public string access_token = null;

    protected override void OnInit(EventArgs args)
    {
        access_token = (Session["Github.OAuth.AccessToken"] ?? "").ToString();

        if (String.IsNullOrEmpty(access_token))
        {
            Response.Redirect("~/startoauth.aspx");
        }
        
        issuesToDisplay = PrintMilestoneWithRoadmapIssues("Roadmap", "Customer Request");

        OrderEntryMode = (Request.QueryString["edit"] == "1");
    }
    
    public Dictionary<GithubMilestone, IEnumerable<GithubIssue>> PrintMilestoneWithRoadmapIssues(params string[] labelsArray)
    {
        // - Only show ones that are Roadmap or Customer Request
       
        // Get the milestones,
        var milestones = JsonUtil.GetAllPagesJson<GithubMilestone>(access_token, "repos/" + repo + "/milestones");

        var top4Milestones = milestones
            .OrderBy(m => JsonUtil.GetMeta(m).Order) // Get the ordering
            .Take(4); // Only show the first 4 milestones


        var issueDictionary = new Dictionary<GithubMilestone, IEnumerable<GithubIssue>>();
        
        // Get issues for each milestone
        foreach( var milestone in top4Milestones )
        {
            IEnumerable<GithubIssue> issues = new GithubIssue[0];

            issues = labelsArray
                .Aggregate(issues, (current, label) => current.Concat(getAllIssuesForLabelAndMilestone(milestone, label)));
            
            var orderedIssues = issues.Distinct().OrderBy(i => JsonUtil.GetMeta(i).Order);

            //if (!orderedIssues.Any())
            //{
            //    continue;
            //}

            issueDictionary.Add(milestone, orderedIssues);
        }

        return issueDictionary;
    }
    
    private IEnumerable<GithubIssue> getAllIssuesForLabelAndMilestone(GithubMilestone milestone, string label)
    {
        string issuesForMilestoneUrlFormat = "repos/" + repo + "/issues";
        const string issuesForMilestoneQueryFormat = "milestone={0}&labels={1}&state={2}";
        
        var openIssues =
            JsonUtil.GetAllPagesJson<GithubIssue>(access_token, issuesForMilestoneUrlFormat, issuesForMilestoneQueryFormat, milestone.Number, label, "open");

        var closedIssues =
            JsonUtil.GetAllPagesJson<GithubIssue>(access_token, issuesForMilestoneUrlFormat, issuesForMilestoneQueryFormat, milestone.Number, label, "closed");

        return openIssues.Concat(closedIssues);
    }

    
    public void PrintIssuesByMilestoneInHuboardOrder()
    {
        var issues = JsonUtil.GetAllPagesJson<GithubIssue>(access_token, "repos/" + repo + "/issues");
        var milestones = new Dictionary<string, GithubMilestone>();

        // Group by milestone
        var issuesByMilestone = issues.GroupBy(i =>
        {
            var id = i.Milestone.Id;

            if (!milestones.ContainsKey(id))
            {
                milestones.Add(id, i.Milestone);
            }

            return id;
        });

        issuesByMilestone = issuesByMilestone.OrderBy(group => JsonUtil.GetMeta(milestones[group.Key]).Order);

        foreach (var group in issuesByMilestone)
        {
            Response.Write("<h1>" + milestones[group.Key].Title + "</h1><ul>\n");
            foreach (var i in group)
            {
                Response.Write("<li>" + i.Number + ": " + i.Title + "</li>\n");
            }
            Response.Write("</ul>\n");
        }
    }
	
</script>

<html>
    <head>
        <style>
            body {
                font: 13px Helvetica, arial, freesans, clean, sans-serif;
                line-height: 1.4;
                color: #333;
            }
           
            h1 small {
                color: #AAA;
                font-size: 15px;
                margin-left: 15px;
            }
           
            td {
                padding: 5px;
                border-bottom: 1px solid black;                
            }
            
            td.issue-number {
                text-align: center;
            }
            
            .label-color {
                width: 10px;
                height: 10px;
                border: 1px solid black;
                display: inline-block;                
            }
            
            .state-indicator {
                display: block;
                font-size: 14px;
                font-weight: bold;
                color: white;
                text-align: center;
                border-radius: 3px;
                background: #999;
                padding: 7px 10px;
                margin-bottom: 10px;
            }
            
            .state-indicator.open {
                background: #6CC644;
            }
            
            .state-indicator.closed {
                background: #BD2C00;
            }
        </style>
        <script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
        <script type="text/javascript" src="//cdnjs.cloudflare.com/ajax/libs/jquery-timeago/0.9.3/jquery.timeago.js"></script>
        <script type="text/javascript">
            jQuery.timeago.settings.allowFuture = true;
            jQuery(document).ready(function () {
                jQuery("abbr.timeago").timeago();
            });
        </script>
    </head>
    <body>
        <% foreach (var pair in issuesToDisplay) { %>
            <h1><%: pair.Key.Title %><small>Due: <abbr class="timeago" title="<%= pair.Key.Due_On.ToString("s") %>" ><%= pair.Key.Due_On.ToLongDateString() %></abbr></small></h1>
            
            <%if( ! pair.Value.Any() ) {%>
              (there are no roadmap or customer request issues for this milestone yet)
            <%} else { %>
            <form name="order-form-<%= pair.Key.Number %>" action="update.aspx" method="POST" enctype="application/x-www-form-urlencoded" >
            <table>
                <thead>
                    <tr>
                        <th>State</th>
                        <th>Number</th>
                        <th>Title</th>
                        <th>Labels</th>
                        <% if (OrderEntryMode) %><th>Order</th>
                    </tr>
                </thead>
                <tbody>
                <% foreach (var issue in pair.Value) { %>
                    <tr>
                        <td>
                            <span class="state-indicator <%= issue.State %>">
                                <%= Char.ToUpper(issue.State[0]) %><%= issue.State.Substring(1) %>
                            </span>
                        </td>
                        <td class="issue-number"><a href="<%= issue.Html_Url %>" target="_blank"><%= issue.Number %></a></td>
                        <td><a href="<%= issue.Html_Url %>" target="_blank"><%= issue.Title %></a></td>
                        <td>
                            <%foreach( var label in issue.Labels.Where( l => !Regex.IsMatch(l.Name, "^[0-9]") && ! l.Name.Contains("Dev")) ){ %>
                                <span class="label-color" style="background-color: #<%=label.Color%>;">&nbsp;</span> <%= label.Name %>
                            <% } %>
                        </td>
                        <% if (OrderEntryMode){ %>
                        <td>
                            <input type="number" maxlength="5" name="order-<%=issue.Number %>" min="1" max="99999" value="<%= issue.Meta.Order %>"/>
                        </td>
                        <% } %>
                    </tr>
                <% } %>
                <% if (OrderEntryMode){ %>
                    <tr>
                        <td colspan="5" align="right">
                            <input type="submit" value="Save Order Changes" />
                        </td>
                    </tr>                
                <% } %>
                </tbody>
            </table>
            
            </form>
            <% } %>
        <% } %>
    </body>
</html>
<%@ Page Language="C#" AutoEventWireup="true"%>
<%@Import namespace="System.Linq"%>

<script runat="server">


    private bool OrderEntryMode;
    private Dictionary<GithubMilestone, IEnumerable<GithubIssue>> issuesToDisplay;
    private string repo = ConfigurationManager.AppSettings["Github.Repo"];
    private string access_token = null;

    protected override void OnInit(EventArgs args)
    {
        OrderEntryMode = (Request.QueryString["edit"] == "1");
        
        issuesToDisplay = Cache[Constants.ISSUE_CACHE_KEY] as Dictionary<GithubMilestone, IEnumerable<GithubIssue>>;

        if (OrderEntryMode || Request.QueryString[Constants.FORCE_CACHE_MODE] == "1")
        {
            issuesToDisplay = null;
        }
        
        // If we have a cached value, we don't need to check for auth or anything like that
        if ( issuesToDisplay != null ) return;
        
        access_token = (Session["Github.OAuth.AccessToken"] ?? "").ToString();

        if (String.IsNullOrEmpty(access_token))
        {
            Response.Redirect("~/startoauth.aspx");
        }
        
        if (issuesToDisplay == null)
        {
            issuesToDisplay = PrintMilestoneWithRoadmapIssues("Roadmap", "Roadmap Review", "Customer Request", "Prospect Request", "Strategic", "Tactical");
            Cache[Constants.ISSUE_CACHE_KEY] = issuesToDisplay;
        }
    }
    
    public Dictionary<GithubMilestone, IEnumerable<GithubIssue>> PrintMilestoneWithRoadmapIssues(params string[] labelsArray)
    {
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

    
    public void PrintIssuesByMilestoneInOrder()
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

    public string GetIssueStateClasses(GithubIssue issue)
    {
        var classes = issue.State;

        if (issue.State == "closed") return classes;
        
        if(issue.Labels.Any(l => l.Name.Contains("Development")))
        {
            classes += " indev";
        }

        if (issue.Labels.Any(l => l.Name == "2 - Review") )
        {
            classes += " review";
        }

        return classes;
    }
    
    public string GetIssueStateForDisplay(GithubIssue issue)
    {
        if (issue.State == "closed")
        {
            return "Done";
        }
        
        if (issue.Labels.Any(l => l.Name.Contains("Development")))
        {
            return "Development";
        }

        if (issue.Labels.Any(l => l.Name == "2 - Review"))
        {
            return "Testing";
        }
        
        if( issue.State == "open")
        {
            return "Not Started";
        }
        
        
        
        return Char.ToUpper(issue.State[0]) + issue.State.Substring(1);
    }
    
    public bool IsDevLabel(GithubLabel label)
    {
        var name = label.Name;
        return !Regex.IsMatch(name, "^[0-9]") && ! name.Contains("Dev") && name != "UI/UX";
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
                background: #A1A1A1;
            }
            
            .state-indicator.closed {
                background: #6CC644;
            }
            
            .state-indicator.indev {
                background: #F2B10D;
            }
            
            .state-indicator.review {
                background: #0157A7;
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
              (there are no roadmap or customer/prospect request issues for this milestone yet)
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
                            <span class="state-indicator <%= GetIssueStateClasses(issue) %>">
                                <%= GetIssueStateForDisplay(issue) %>
                            </span>
                        </td>
                        <td class="issue-number"><a href="<%= issue.Html_Url %>" target="_blank"><%= issue.Number %></a></td>
                        <td><a href="<%= issue.Html_Url %>" target="_blank"><%= issue.Title %></a></td>
                        <td>
                            <%foreach( var label in issue.Labels.Where(IsDevLabel) ){ %>
                                <span class="label-color" style="background-color: #<%=label.Color%>;">&nbsp;</span> <%= label.Name %>
                            <% } %>
                        </td>
                        <% if (OrderEntryMode){ %>
                        <td>
                            <input type="number" maxlength="5" name="order-<%=issue.Number %>" min="1" max="100000" value="<%= issue.Meta.Order %>"/>
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
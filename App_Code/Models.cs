using System;

public class GithubIssue
{
    private string _body;
    public string Url { get; set; }
    public string Html_Url { get; set; }
    public string Number { get; set; }
    public string State { get; set; }
    public string Title { get; set; }
    public GithubMilestone Milestone { get; set; }
    public string Assignee { get; set; }
    public GithubLabel[] Labels { get; set; }
    public string Body
    {
        get { return _body; }
        set
        {
            _body = value;
            Meta = JsonUtil.GetMeta(_body);
        }
    }
    public GithubUser User { get; set; }
    public string Id { get; set; }
    public ManagerPantsMeta Meta { get; private set; }

    public bool Equals(GithubIssue other)
    {
        if (ReferenceEquals(null, other)) return false;
        if (ReferenceEquals(this, other)) return true;
        return Equals(other.Id, Id);
    }

    public override bool Equals(object obj)
    {
        if (ReferenceEquals(null, obj)) return false;
        if (ReferenceEquals(this, obj)) return true;
        if (obj.GetType() != typeof (GithubIssue)) return false;
        return Equals((GithubIssue) obj);
    }

    public override int GetHashCode()
    {
        return (Id != null ? Id.GetHashCode() : 0);
    }
}

public class BodyUpdate
{
    public BodyUpdate(string newBody, string token)
    {
        body = newBody;
        access_token = token;
    }

    public string body { get; set; }
    public string access_token { get; set; }
}

public class ManagerPantsMeta
{
    public ManagerPantsMeta()
    {
        Order = 100000;
    }

    public int Order { get; set; }
    public string TShirtSize { get; set; }

    public static ManagerPantsMeta Default()
    {
        return new ManagerPantsMeta();
    }
}

public class GithubLabel
{
    public string Url { get; set; }
    public string Name { get; set; }
    public string Color { get; set; }
}

public class GithubUser
{
    public string Gravatar_id { get; set; }
    public string Avatar_Url { get; set; }
    public string Login { get; set; }
    public int? Id { get; set; }
    public string Url { get; set; }
}

public class GithubMilestone
{
    public DateTime Due_On { get; set; }
    public string Title { get; set; }
    public string Number { get; set; }
    public string Id { get; set; }
    public string Description { get; set; }
    public string Url { get; set; }
    public int? Closed_Issues { get; set; }
    public int? Open_Issues { get; set; }
    public string State { get; set; }
}

public class Auth
{
    public string Token { get; set; }
}
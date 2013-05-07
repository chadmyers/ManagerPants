using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text.RegularExpressions;
using ServiceStack.Text;

public static class JsonUtil
{
    private static readonly Regex MetaRegex = new Regex("@managerpants:(?<data>.*)", RegexOptions.IgnoreCase);
    

    public static List<T> GetAllPagesJson<T>(string access_token, string route, string extendedQuery = null, params object[] rawQueryArgs)
    {
        var page = 1;
        var lastPageReached = false;
        var allItems = new List<T>(1000);

        while (!lastPageReached)
        {
            var query = "?access_token={0}&page={1}&per_page=100".Fmt(access_token, page);
            if( !String.IsNullOrEmpty(extendedQuery) )
            {
                var queryArgs = new object[rawQueryArgs.Length];
                for (var i = 0; i < queryArgs.Length; i++ )
                {
                    queryArgs[i] = rawQueryArgs[i].ToString().UrlEncode();
                }

                query = string.Concat(query, "&", String.Format(extendedQuery, queryArgs));
            }
            var url = string.Concat(Constants.GithubApiBaseUrl, route, query);
            var curPageItems = GetStringFromUrl(url, "application/vnd.github.v3.full+json", res =>
                                                      {
                                                          var linkHeader = res.Headers["Link"];
                                                          if( String.IsNullOrEmpty(linkHeader) )
                                                          {
                                                              lastPageReached = true;
                                                          }
                                                          else
                                                          {
                                                              var links = linkHeader.Split(',');
                                                              // Parse the link/rel stuff into a dictionary
                                                              var linkDict = links.ToDictionary(l => l.Split(';')[1].Replace("rel=", "").Replace("\"", "").Trim(), l => Regex.Match(l.Split(';')[0], "&page=(?<page>[^&]*)&per_page").Groups["page"].Value.Trim());
                                                              lastPageReached = (!linkDict.ContainsKey("last") || linkDict["last"] == "1");
                                                          }
                                                      }).FromJson<List<T>>();

            allItems.AddRange(curPageItems);

            page++;
        }

        return allItems;
    }

    public static string GetStringFromUrl(string url, string acceptContentType = "*/*", Action<HttpWebResponse> responseFilter = null)
    {
        var webReq = (HttpWebRequest)WebRequest.Create(url);
        webReq.Accept = acceptContentType;
        webReq.UserAgent = "Dovetail/ManagerPants";
        webReq.Headers.Add(HttpRequestHeader.AcceptEncoding, "gzip,deflate");
        webReq.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
        using (var webRes = webReq.GetResponse())
        using (var stream = webRes.GetResponseStream())
        using (var reader = new StreamReader(stream))
        {
            if (responseFilter != null)
            {
                responseFilter((HttpWebResponse)webRes);
            }
            return reader.ReadToEnd();
        }
    }

    public static string PostAndGetStringFromUrl(string access_token, string url, string postData, string acceptContentType = "*/*", string contentType = "application/x-www-form-urlencoded", Action<HttpWebRequest> modifier = null)
    {
        var webReq = (HttpWebRequest)WebRequest.Create(url);
        webReq.Method = "POST";
        var bytes = System.Text.Encoding.ASCII.GetBytes(postData);
        webReq.ContentLength = bytes.Length;
        webReq.ContentType = contentType;
        webReq.Accept = acceptContentType;
        webReq.Headers.Add(HttpRequestHeader.AcceptEncoding, "gzip,deflate");
        if (access_token != null)
        {
            webReq.Headers.Add(HttpRequestHeader.Authorization, "token " + access_token);
        }
        if (modifier != null) modifier(webReq);
        webReq.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
        webReq.GetRequestStream().Write(bytes, 0, bytes.Length);
        using (var webRes = webReq.GetResponse())
        using (var stream = webRes.GetResponseStream())
        using (var reader = new StreamReader(stream))
        {
            return reader.ReadToEnd();
        }
    }

    public static string PatchAndGetStringFromUrl(string access_token, string url, string postData, Action<HttpWebRequest> modifier)
    {
        var webReq = (HttpWebRequest)WebRequest.Create(url);
        webReq.Method = "PATCH";
        var bytes = System.Text.Encoding.UTF8.GetBytes(postData);
        webReq.ContentLength = bytes.Length;
        webReq.ContentType = "application/vnd.github.v3.full+json";
        webReq.Accept = "application/vnd.github.v3.full+json";
        webReq.Headers.Add(HttpRequestHeader.Authorization, "token " + access_token);
        webReq.Headers.Add(HttpRequestHeader.AcceptEncoding, "gzip,deflate");
        modifier(webReq);
        webReq.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
        webReq.GetRequestStream().Write(bytes, 0, bytes.Length);
        using (var webRes = webReq.GetResponse())
        using (var stream = webRes.GetResponseStream())
        using (var reader = new StreamReader(stream))
        {
            return reader.ReadToEnd();
        }
    }
    
    public static ManagerPantsMeta GetMeta(GithubIssue issue)
    {
        return GetMeta(issue.Body);
    }

    public static ManagerPantsMeta GetMeta(GithubMilestone milestone)
    {
        return GetMeta(milestone.Description);
    }

    public static ManagerPantsMeta GetMeta(string description)
    {
        if (String.IsNullOrEmpty(description)) return ManagerPantsMeta.Default();
        var pantsMetaRaw = MetaRegex.Match(description).Groups["data"].Value;
        if (String.IsNullOrEmpty(pantsMetaRaw)) return ManagerPantsMeta.Default();

        return pantsMetaRaw.FromJson<ManagerPantsMeta>();
    }

    public static string SetMeta(ManagerPantsMeta meta, string description)
    {
        var json = meta.ToJson();

        if (MetaRegex.IsMatch(description))
        {
            // Replace
            description = MetaRegex.Replace(description, String.Format("@managerpants:{0}", json));
        }
        else
        {
            // New
            description += String.Format("\r\n<!--\r\n@managerpants:{0}\r\n-->\r\n", json);
        }
        
        return description;
    }

    //public void PrintNewAuthToken(string authPass)
    //{
    //    var authUser = "username";
    //    var authValue = Convert.ToBase64String(System.Text.Encoding.ASCII.GetBytes(authUser + ":" + authPass));
    //    var authUrl = GithubApiBaseUrl + "authorizations";
    //    var rawResponse = PostAndGetStringFromUrl(authUrl, "{\"scopes\":[\"repo\"], \"note\":\"GH issue status viewer\"}", r => { r.Headers["Authorization"] = "Basic " + authValue; });
    //    var authData = rawResponse.FromJson<Auth>();

    //    Response.Write("<span>" + authData.Token + "</span>");
    //}
}
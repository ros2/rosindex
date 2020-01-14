
function writeIssuesLists(issues) {
  help_wanted_list = "";
  good_first_issues_list = "";
  console.log(issues.length);
  for (var i=0; i < issues.length; i++) {
    var issue = issues[i];
    if (issue['state'] != "open") {
      continue;
    }
    var labels = issue['labels'];
    for (var k=0; k < labels.length; k++) {
      var label = labels[k];
      // console.log(label);
      if (label['name'] == 'help wanted') {
        help_wanted_list += '<a href="'
          + issue['html_url'] + '">' + issue['title'] + '</a><br>';
      }
      if (label['name'] == 'good first issue') {
        good_first_issues_list += '<a href="'
          + issue['html_url'] + '">' + issue['title'] + '</a><br>';
      }
    }
  }
  $('.contribute-lists-help-wanted').each(function() {
    $(this).html(help_wanted_list);
  });
  $('.contribute-lists-good-first-issue').each(function() {
    $(this).html(good_first_issues_list);
  });
}


function writePRsLists(prs) {
  prs_list = "";
  for (var i=0; i < prs.length; i++) {
    var pr = prs[i];
    if (pr['state'] != "open") {
      continue;
    }
    prs_list += '<a href="'
      + pr['html_url'] + '">' + pr['title'] + '</a><br>';
  }
  $('.contribute-lists-prs').each(function() {
    $(this).html(prs_list);
  });
}


function setupContributeLists(repo_uri) {
  // Expected uri pattern:
  // "https://github.com/<owner>/<repo>[.git]"
  if (!repo_uri.includes("github.com")) {
    $('.contribute-lists').each(function() {
      $(this).html("NOT A GITHUB REPO");
    });
    return;
  }
  // Target query pattern:
  // "https://api.github.com/repos/<owner>/<repo>/pulls"
  api_uri = repo_uri.replace(/\.git$/, "").replace("github.com", "api.github.com/repos");
  console.log(api_uri + "/issues?state=open&per_page=100");
  fetch(api_uri + "/issues?state=open&per_page=100")
    .then(response => response.json())
    .then(data => {
      writeIssuesLists(data);
    })
    .catch(error => console.error(error));
  fetch(api_uri + "/pulls?state=open&per_page=100")
    .then(response => response.json())
    .then(data => {
      writePRsLists(data);
    })
    .catch(error => console.error(error));
}

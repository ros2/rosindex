

function populateContributeLists(list, items) {
  html = '<table class="table table-condensed table-striped"><tbody>';
  for (var i=0; i < items.length; i++) {
    var item = items[i];
    html += '<tr><td><a href="'
      + item['html_url'] + '">' + item['title'] + '</a></td></tr>';
  }
  html += '</tbody>';
  $('.contribute-lists-'+list).each(function() {
    $(this).html(html);
  });
  $('.contribute-lists-'+list+'-count').each(function() {
    $(this).text(items.length);
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
  fetch(api_uri + "/issues?state=open&labels=help%20wanted&per_page=100")
    .then(response => response.json())
    .then(data => {
      populateContributeLists('help-wanted', data);
    })
    .catch(error => console.error(error));
  fetch(api_uri + "/issues?state=open&labels=good%20first%20issue&per_page=100")
    .then(response => response.json())
    .then(data => {
      populateContributeLists('good-first-issue', data);
    })
    .catch(error => console.error(error));
  fetch(api_uri + "/pulls?state=open&per_page=100")
    .then(response => response.json())
    .then(data => {
      populateContributeLists('pull-requests', data);
    })
    .catch(error => console.error(error));
}


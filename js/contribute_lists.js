

function populateContributeLists(list, items) {
  html = '<table class="table table-condensed table-striped"><tbody>';
  for (var i=0; i < items.length; i++) {
    var item = items[i];
    html += '<tr><td><a href="' + item['html_url'] + '">#';
    html += item['number'] + '</td><td>' + item['title'] + '</a></td></tr>';
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
    return;
  }
  // Target query pattern:
  // "https://api.github.com/repos/<owner>/<repo>/pulls"
  api_uri = repo_uri.replace(/\.git$/, "").replace("github.com", "api.github.com/repos");
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


// Javascript to enable link to tab
$(function() {
  var url = document.location.toString();
  if (url.match('#')) {
    $('.nav-tabs a[href=#'+url.split('#')[1]+']').tab('show');
  }
  // Change hash for page-reload
  $('.nav-tabs a').on('shown', function (e) {
      window.location.hash = e.target.hash;
  });

  $("a[href^=#]").on("click", function(e) {
     e.preventDefault();
     history.pushState({}, "", this.href);
  });
});

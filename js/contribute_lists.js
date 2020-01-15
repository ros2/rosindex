

function populateContributeLists(list, items) {
  html = "";
  for (var i=0; i < items.length; i++) {
    var item = items[i];
    html += '<a href="'
      + item['html_url'] + '">' + item['title'] + '</a><br>';
  }
  var list_class = ''
  $('.contribute-lists-'+list).each(function() {
    $(this).html(html);
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

// Enable links to contribute list tabs
$(function() {
  var url = document.location.toString();
  if (url.match('#')) {
      $('.nav-tabs a[href=#'+url.split('#')[1]+']').tab('show') ;
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

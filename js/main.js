// No framework, no build step. Two small jobs.

// Footer year.
var yearEl = document.getElementById('year');
if (yearEl) yearEl.textContent = new Date().getFullYear();

// Click-to-load YouTube.
//
// Markup:  <div class="video" data-youtube="VIDEO_ID" data-title="..."></div>
//
// A real <iframe> pulls roughly a megabyte of Google script into the page on
// load, whether or not anyone watches. Instead we show YouTube's thumbnail and
// only build the iframe on click, with autoplay so the click still starts
// playback. youtube-nocookie.com avoids setting tracking cookies until then.
document.querySelectorAll('.video[data-youtube]').forEach(function (box) {
  var id = box.dataset.youtube;
  var title = box.dataset.title || 'Video';

  // Placeholder until a real id is filled in, so unfinished pages do not
  // render a broken YouTube thumbnail.
  if (!id || id.indexOf('TODO') === 0) {
    var note = document.createElement('div');
    note.className = 'video-todo';
    note.textContent = 'Video coming soon';
    box.appendChild(note);
    return;
  }

  var poster = document.createElement('button');
  poster.className = 'video-poster';
  poster.type = 'button';
  poster.setAttribute('aria-label', 'Play: ' + title);
  poster.style.backgroundImage =
    "url('https://i.ytimg.com/vi/" + id + "/maxresdefault.jpg')";

  poster.addEventListener('click', function () {
    var frame = document.createElement('iframe');
    frame.src = 'https://www.youtube-nocookie.com/embed/' + id +
                '?autoplay=1&rel=0';
    frame.title = title;
    frame.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; ' +
                  'gyroscope; picture-in-picture; web-share';
    frame.allowFullscreen = true;
    box.replaceChildren(frame);
  });

  box.appendChild(poster);
});

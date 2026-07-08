// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import darkModeHook from "../vendor/dark_mode"

let Hooks = {}
Hooks.DarkThemeToggle = darkModeHook

Hooks.self_press_button = {
  loadMore(entries) {
    const target = entries[0];
    if (target.isIntersecting && !this.el.disabled) {
      this.el.click();
    }
  },
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => this.loadMore(entries), {
        root: null,
        rootMargin: "0px",
        threshold: 0
      }
    );
    this.observer.observe(this.el);
  },
  beforeDestroy() {
    this.observer.unobserve(this.el);
  }
}
Hooks.sticky_columns_general = {
  mounted(){
    var l_col1 = document.getElementsByClassName("sticky-col-left-1");
    var l_col2 = document.getElementsByClassName("sticky-col-left-2");
    var l_col3 = document.getElementsByClassName("sticky-col-left-3");

    let left_offset = new Array();
    left_offset[0] = Number(this.el.dataset.left_offset_1);
    left_offset[1] = Number(this.el.dataset.left_offset_2);

    for (i = 0; i < left_offset.length; i++) {
      if(isNaN(left_offset[i])) {
        left_offset[i] = 0;
      }
    }

    var r_col1 = document.getElementsByClassName("sticky-col-right-1");
    var r_col2 = document.getElementsByClassName("sticky-col-right-2");
    var r_col3 = document.getElementsByClassName("sticky-col-right-3");

    let right_offset = new Array();
    right_offset[0] = Number(this.el.dataset.right_offset_1);
    right_offset[1] = Number(this.el.dataset.right_offset_2);

    for (i = 0; i < right_offset.length; i++) {
      if(isNaN(right_offset[i])) {
        right_offset[i] = 0;
      }
    }


    if(!(l_col1[0] === undefined) && !(l_col2[0] === undefined)) {
      var l_col1_width = Math.floor(l_col1[0].getBoundingClientRect()?.width) + left_offset[0];
      var l_col2_width = Math.floor(l_col2[0].getBoundingClientRect()?.width) + left_offset[1];

      for (var i = 0; i < l_col1.length; i++) {
        l_col2[i].style.left = `${l_col1_width}px`;
        if(!(l_col3[i] === undefined)) {
          l_col3[i].style.left = `${l_col1_width + l_col2_width}px`;
        }
      }
    }

    if(!(r_col1[0] === undefined) && !(r_col2[0] === undefined)) {
      var r_col1_width = Math.floor(r_col1[0].getBoundingClientRect()?.width) + right_offset[0];
      var r_col2_width = Math.floor(r_col2[0].getBoundingClientRect()?.width) + right_offset[1];

      for (var i = 0; i < r_col1.length; i++) {
        r_col2[i].style.right = `${r_col1_width}px`;
        if(!(r_col3[i] === undefined)) {
          r_col3[i].style.right = `${r_col1_width + r_col2_width}px`;
        }
      }
    }
  },
  updated() {
    var l_col1 = document.getElementsByClassName("sticky-col-left-1");
    var l_col2 = document.getElementsByClassName("sticky-col-left-2");
    var l_col3 = document.getElementsByClassName("sticky-col-left-3");

    let left_offset = new Array();
    left_offset[0] = Number(this.el.dataset.left_offset_1);
    left_offset[1] = Number(this.el.dataset.left_offset_2);

    for (i = 0; i < left_offset.length; i++) {
      if(isNaN(left_offset[i])) {
        left_offset[i] = 0;
      }
    }

    var r_col1 = document.getElementsByClassName("sticky-col-right-1");
    var r_col2 = document.getElementsByClassName("sticky-col-right-2");
    var r_col3 = document.getElementsByClassName("sticky-col-right-3");

    let right_offset = new Array();
    right_offset[0] = Number(this.el.dataset.right_offset_1);
    right_offset[1] = Number(this.el.dataset.right_offset_2);

    for (i = 0; i < right_offset.length; i++) {
      if(isNaN(right_offset[i])) {
        right_offset[i] = 0;
      }
    }


    if(!(l_col1[0] === undefined) && !(l_col2[0] === undefined)) {
      var l_col1_width = Math.floor(l_col1[0].getBoundingClientRect()?.width) + left_offset[0];
      var l_col2_width = Math.floor(l_col2[0].getBoundingClientRect()?.width) + left_offset[1];

      for (var i = 0; i < l_col1.length; i++) {
        l_col2[i].style.left = `${l_col1_width}px`;
        if(!(l_col3[i] === undefined)) {
          l_col3[i].style.left = `${l_col1_width + l_col2_width}px`;
        }
      }
    }

    if(!(r_col1[0] === undefined) && !(r_col2[0] === undefined)) {
      var r_col1_width = Math.floor(r_col1[0].getBoundingClientRect()?.width) + right_offset[0];
      var r_col2_width = Math.floor(r_col2[0].getBoundingClientRect()?.width) + right_offset[1];

      for (var i = 0; i < r_col1.length; i++) {
        r_col2[i].style.right = `${r_col1_width}px`;
        if(!(r_col3[i] === undefined)) {
          r_col3[i].style.right = `${r_col1_width - r_col2_width}px`;
        }
      }
    }
  }
}
Hooks.copy_to_clipboard = {
  mounted() {
    this.handleEvent("copy_to_clipboard", ({text}) => {
      navigator.clipboard.writeText(text).then(() => {
        // Optional: show success feedback
        console.log("Copied to clipboard");
        console.log(text)
      }).catch(err => {
        console.error("Failed to copy: ", err);
      });
    });
  }
}

// Renders a UTC ISO8601 timestamp (data-utc="...") in the browser's local
// timezone. Read-only display - pair with LocalDatetimeInput for editing.
Hooks.LocalTime = {
  format() {
    const utc = this.el.dataset.utc;
    if (!utc) {
      this.el.textContent = "";
      return;
    }
    const date = new Date(utc);
    if (isNaN(date.getTime())) {
      this.el.textContent = "";
      return;
    }
    this.el.textContent = date.toLocaleString(undefined, {dateStyle: "medium", timeStyle: "short"});
  },
  mounted() { this.format(); },
  updated() { this.format(); }
}

// Renders a running HH:MM:SS elapsed-time readout counting up from a UTC
// ISO8601 timestamp (data-start="..."), optionally on top of a fixed
// data-base-seconds offset (e.g. time already logged before this run).
// Ticks client-side every second so it doesn't require a server round-trip.
Hooks.ElapsedTimer = {
  format(totalSeconds) {
    const seconds = Math.max(0, Math.floor(totalSeconds));
    const pad = (n) => String(n).padStart(2, "0");
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${pad(hours)}:${pad(minutes)}:${pad(secs)}`;
  },
  tick() {
    if (!this.start) {
      this.el.textContent = this.format(this.base);
      return;
    }
    this.el.textContent = this.format(this.base + (Date.now() - this.start.getTime()) / 1000);
  },
  startTimer() {
    const utc = this.el.dataset.start;
    const date = utc ? new Date(utc) : null;
    this.start = date && !isNaN(date.getTime()) ? date : null;
    this.base = parseFloat(this.el.dataset.baseSeconds || "0");
    this.tick();
    if (this.interval) clearInterval(this.interval);
    if (this.start) this.interval = setInterval(() => this.tick(), 1000);
  },
  mounted() { this.startTimer(); },
  updated() { this.startTimer(); },
  destroyed() { if (this.interval) clearInterval(this.interval); }
}

function localDatetimeInputValue(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

// Pairs a visible <input type="datetime-local"> (this.el, edited/displayed in
// the browser's local time) with a hidden input (referenced by
// data-hidden-id) that holds the canonical UTC ISO8601 value actually
// submitted to the server. Syncs hidden -> visible (UTC -> local) whenever
// the hidden value changes from the server, and visible -> hidden
// (local -> UTC) as the user edits.
Hooks.LocalDatetimeInput = {
  mounted() {
    this.hidden = document.getElementById(this.el.dataset.hiddenId);
    this.syncFromHidden();
    this.el.addEventListener("input", () => this.syncToHidden());
  },
  updated() {
    this.hidden = document.getElementById(this.el.dataset.hiddenId);
    this.syncFromHidden();
  },
  syncFromHidden() {
    if (!this.hidden) return;
    const value = this.hidden.value;
    if (value === this._lastHidden) return;
    this._lastHidden = value;
    if (!value) {
      this.el.value = "";
      return;
    }
    const date = new Date(value);
    if (isNaN(date.getTime())) return;
    this.el.value = localDatetimeInputValue(date);
  },
  syncToHidden() {
    if (!this.hidden || !this.el.value) return;
    const date = new Date(this.el.value);
    if (isNaN(date.getTime())) return;
    this._lastHidden = date.toISOString();
    this.hidden.value = this._lastHidden;
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks}, )

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

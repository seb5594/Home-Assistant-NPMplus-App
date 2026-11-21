/*
 * NPMplus for Home Assistant: browser side of the ingress integration.
 *
 * Home Assistant shows the admin UI in an iframe below /api/hassio_ingress/<token>/, but the UI
 * was written for the root of its own host. This script closes the gap without touching the UI:
 *
 *   - Requests for root-relative URLs (/api/..., /images/..., lazily loaded chunks) are moved
 *     below the ingress path.
 *   - The history API keeps the ingress path in the address of the frame, so a reload or an
 *     expired session lands on the UI again instead of on Home Assistant.
 *   - The router of the UI reads its location from window.__npmplusLocation (patched in at image
 *     build time), which shows the route without the ingress path.
 *   - A support footer is appended to the footer of the UI.
 *
 * Opened directly, without the ingress path, the script does nothing.
 */
(function () {
  "use strict";

  var script = document.currentScript;
  var ingress = /^\/api\/hassio_ingress\/[^/]+/.exec(location.pathname);
  if (!ingress) {
    return;
  }
  var prefix = ingress[0];

  var SUPPORT = {
    project: "https://github.com/seb5594/Home-Assistant-NPMplus-App",
    paypal: "https://paypal.me/seb5594",
    coffee: "https://buymeacoffee.com/seb5594",
  };

  // Emoji are written as escapes so the file reads the same in every encoding.
  var HEART = "\u2764\uFE0F";
  var GERMANY = "\uD83C\uDDE9\uD83C\uDDEA";
  var COFFEE = "\u2615";
  var BEER = "\uD83C\uDF7A";

  // ---- URL handling -------------------------------------------------------------------------

  function isRootRelative(url) {
    return typeof url === "string" && url.charAt(0) === "/" && url.charAt(1) !== "/" &&
      url !== prefix && url.indexOf(prefix + "/") !== 0;
  }

  // Absolute URLs of this host count as well: the module preloader resolves paths to them.
  function withPrefix(url) {
    if (typeof url === "string" && url.indexOf(location.origin + "/") === 0) {
      return location.origin + withPrefix(url.slice(location.origin.length));
    }
    return isRootRelative(url) ? prefix + url : url;
  }

  function escapeRegExp(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  // The route as the UI knows it: the address of the frame without the ingress path.
  Object.defineProperty(window, "__npmplusLocation", {
    value: {
      get pathname() { return location.pathname.slice(prefix.length) || "/"; },
      get search() { return location.search; },
      get hash() { return location.hash; },
    },
  });

  // ---- Network requests ---------------------------------------------------------------------

  var nativeFetch = window.fetch;
  window.fetch = function (input, init) {
    return nativeFetch.call(this, typeof input === "string" ? withPrefix(input) : input, init);
  };

  var nativeOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    var args = Array.prototype.slice.call(arguments);
    args[1] = withPrefix(url);
    return nativeOpen.apply(this, args);
  };

  // ---- History and elements -----------------------------------------------------------------

  ["pushState", "replaceState"].forEach(function (method) {
    var native = History.prototype[method];
    History.prototype[method] = function (state, title, url) {
      return native.call(this, state, title, typeof url === "string" ? withPrefix(url) : url);
    };
  });

  var nativeSetAttribute = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (name, value) {
    var attribute = String(name).toLowerCase();
    return nativeSetAttribute.call(this, name, attribute === "src" || attribute === "href" ? withPrefix(value) : value);
  };

  // Elements that load resources when the property is set (e.g. the preload of a lazy chunk).
  [[HTMLImageElement, "src"], [HTMLScriptElement, "src"], [HTMLLinkElement, "href"],
    [HTMLSourceElement, "src"]].forEach(function (entry) {
    var descriptor = Object.getOwnPropertyDescriptor(entry[0].prototype, entry[1]);
    if (!descriptor || !descriptor.set) {
      return;
    }
    Object.defineProperty(entry[0].prototype, entry[1], {
      configurable: true,
      enumerable: descriptor.enumerable,
      get: descriptor.get,
      set: function (value) { descriptor.set.call(this, withPrefix(value)); },
    });
  });

  // Inline styles such as background-image: url(/images/...) are set through the style object.
  // They are corrected through that object as well: the content security policy of the UI
  // blocks rewriting the style attribute, but not changes made with the CSSOM.
  var styleUrl = new RegExp("url\\((['\"]?)/(?!/|" + escapeRegExp(prefix.slice(1)) + ")", "g");

  function fixInlineStyle(element) {
    var style = element.style;
    for (var index = 0; style && index < style.length; index++) {
      var property = style[index];
      var value = style.getPropertyValue(property);
      var fixed = value.replace(styleUrl, "url($1" + prefix + "/");
      if (fixed !== value) {
        style.setProperty(property, fixed, style.getPropertyPriority(property));
      }
    }
  }

  // ---- Support footer -----------------------------------------------------------------------

  function create(tag, className, text) {
    var element = document.createElement(tag);
    if (className) { element.className = className; }
    if (text) { element.textContent = text; }
    return element;
  }

  function link(label, url) {
    var anchor = create("a", "", label);
    anchor.href = url;
    anchor.target = "_blank";
    anchor.rel = "noopener noreferrer";
    return anchor;
  }

  function buildFooter() {
    var footer = create("div", "npmplus-app-footer");
    footer.appendChild(link("NPMplus for Home Assistant " + script.getAttribute("data-version"), SUPPORT.project));
    footer.appendChild(create("span", "", "Made with " + HEART + " in Germany " + GERMANY));
    footer.appendChild(link("Support my work " + COFFEE + BEER, SUPPORT.coffee));
    footer.appendChild(link("PayPal", SUPPORT.paypal));
    return footer;
  }

  function addFooter() {
    var host = document.querySelector("footer.footer");
    if (host && !host.querySelector(".npmplus-app-footer")) {
      host.appendChild(buildFooter());
    }
  }

  // ---- Start --------------------------------------------------------------------------------

  var stylesheet = create("link");
  stylesheet.rel = "stylesheet";
  stylesheet.href = prefix + "/_npmplus_app/footer.css";
  document.head.appendChild(stylesheet);

  // The UI renders its pages after load and replaces them on every navigation, so the footer and
  // inline styles are checked whenever the document changes.
  new MutationObserver(function (records) {
    records.forEach(function (record) {
      if (record.type === "attributes") {
        fixInlineStyle(record.target);
        return;
      }
      record.addedNodes.forEach(function (node) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          fixInlineStyle(node);
          node.querySelectorAll("[style*='url(']").forEach(fixInlineStyle);
        }
      });
    });
    addFooter();
  }).observe(document, { subtree: true, childList: true, attributes: true, attributeFilter: ["style"] });
}());

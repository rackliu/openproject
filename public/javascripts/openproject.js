window.OpenProject = (function ($) {
 /**
   * OpenProject instance methods
   */
  var OP = function (options) {
    options = options || {};
    this.urlRoot = options.urlRoot || "";

    if (!/\/$/.test(this.urlRoot)) {
      this.urlRoot += '/';
    }
  };

  OP.prototype.getFullUrl = function (url) {
    if (!url) {
      return this.urlRoot;
    }

    if (/^\//.test(url)) {
      url = url.substr(1);
    }

    return this.urlRoot + url;
  };

  OP.prototype.fetchProjects = function (callback) {
    if (this.projects) {
      callback.call(this, this.projects);
      return;
    }

    jQuery.getJSON(
        this.getFullUrl("/projects/level_list.json"),
        function (data, textStatus, jqXHR) {
          this.projects = data.projects;
          callback.call(this, this.projects);
        }
      );
  };

  /**
   * Static OpenProject Helper methods
   */

  OP.Helpers = (function () {
    var Helpers = {};

    var REGEXP_ESCAPE = /([\\\.\+\*\?\[\^\]\$\(\)\{\}\=\|\:\!><])/g;

    Helpers.regexp_escape = function (str) {
      // taken from http://stackoverflow.com/questions/280793/
      return (str+'').replace(REGEXP_ESCAPE, "\\$1");
    };

    Helpers.Search = {};

    var REGEXP_TOKEN = /[\s\.\-\/,]+/;

    Helpers.Search.tokenize = function (name, separators) {
      var regexp;

      if (jQuery.isArray(separators)) {
        regexp = new RegExp(OpenProject.Helpers.regexp_escape(separators.join("")) + "+");
      }
      else if (separators instanceof RegExp) {
        regexp = separators;
      }
      else {
        regexp = REGEXP_TOKEN;
      }

      return jQuery.grep(name.split(regexp), function (t) { return t.length > 0; });
    },

    Helpers.Search.matcher = (function () {
      var removeOnce, match, matrixMatch;

      removeOnce = function (array, element) {
        var removed = false;
        return jQuery.grep(array, function (t) {
          if (removed) {
            return true;
          }
          if (t === element) {
            removed = true;
            return false;
          }
          return true;
        });
      };

      match = function (query, t) {
        return function (s) {
          return $.fn.select2.defaults.matcher.call(query, t, s);
        };
      };

      matchMatrix = function (query, parts, tokens) {
        var candidates = jQuery.grep(tokens, match(query, parts[0]));

        if (parts.length === 1) {
          // do the remaining tokens match the one remaining part?
          return candidates.length > 0;
        }

        parts = parts.slice(1);

        for (var i = 0; i < candidates.length; i++) {
          if (matchMatrix(query, parts, removeOnce(tokens, candidates[i]))) {
            return true;
          }
        }

        return false;
      };

      return function (term, name, token) {
        // support basic match syntax if necessary
        if (match(this, term)(name)) {
          return true;
        }

        if (token === undefined) {
          return false;
        }

        return matchMatrix(
            this,
            OpenProject.Helpers.Search.tokenize(term, /\s+/),
            token);
      };
    })();


    return Helpers;
  })();

  return OP;
})(jQuery);

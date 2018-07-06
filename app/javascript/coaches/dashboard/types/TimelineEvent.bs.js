// Generated by BUCKLESCRIPT VERSION 3.1.5, PLEASE EDIT WITH CARE
'use strict';

var List = require("bs-platform/lib/js/list.js");
var Pervasives = require("bs-platform/lib/js/pervasives.js");
var Belt_Option = require("bs-platform/lib/js/belt_Option.js");
var Json_decode = require("@glennsl/bs-json/src/Json_decode.bs.js");
var File$ReactTemplate = require("./File.bs.js");
var Link$ReactTemplate = require("./Link.bs.js");
var DateTime$ReactTemplate = require("./DateTime.bs.js");

function parseStatus(grade, status) {
  switch (status) {
    case "Needs Improvement" : 
        return /* NeedsImprovement */2;
    case "Not Accepted" : 
        return /* NotAccepted */0;
    case "Pending" : 
        return /* Pending */1;
    case "Verified" : 
        return /* Verified */[Belt_Option.getExn(grade)];
    default:
      return Pervasives.failwith("Invalid Status " + (status + " received!"));
  }
}

function parseGrade(grade) {
  if (grade) {
    var grade$1 = grade[0];
    switch (grade$1) {
      case "good" : 
          return /* Some */[/* Good */0];
      case "great" : 
          return /* Some */[/* Great */1];
      case "wow" : 
          return /* Some */[/* Wow */2];
      default:
        return Pervasives.failwith("Invalid Grade " + (grade$1 + " received!"));
    }
  } else {
    return /* None */0;
  }
}

function statusString(status) {
  if (typeof status === "number") {
    switch (status) {
      case 0 : 
          return "Not Accepted";
      case 1 : 
          return "Pending";
      case 2 : 
          return "Needs Improvement";
      
    }
  } else {
    return "Verified";
  }
}

function gradeString(grade) {
  switch (grade) {
    case 0 : 
        return "good";
    case 1 : 
        return "great";
    case 2 : 
        return "wow";
    
  }
}

function decode(json) {
  var grade = parseGrade(Json_decode.optional((function (param) {
              return Json_decode.field("grade", Json_decode.string, param);
            }), json));
  return /* record */[
          /* id */Json_decode.field("id", Json_decode.$$int, json),
          /* title */Json_decode.field("title", Json_decode.string, json),
          /* description */Json_decode.field("description", Json_decode.string, json),
          /* status */parseStatus(grade, Json_decode.field("status", Json_decode.string, json)),
          /* eventOn */DateTime$ReactTemplate.parse(Json_decode.field("eventOn", Json_decode.string, json)),
          /* startupId */Json_decode.field("startupId", Json_decode.$$int, json),
          /* startupName */Json_decode.field("startupName", Json_decode.string, json),
          /* founderId */Json_decode.field("founderId", Json_decode.$$int, json),
          /* founderName */Json_decode.field("founderName", Json_decode.string, json),
          /* submittedAt */DateTime$ReactTemplate.parse(Json_decode.field("submittedAt", Json_decode.string, json)),
          /* links */Json_decode.field("links", (function (param) {
                  return Json_decode.list(Link$ReactTemplate.decode, param);
                }), json),
          /* files */Json_decode.field("files", (function (param) {
                  return Json_decode.list(File$ReactTemplate.decode, param);
                }), json)
        ];
}

function forStartupId(startupId, tes) {
  return List.filter((function (te) {
                  return te[/* startupId */5] === startupId;
                }))(tes);
}

function verificationPending(tes) {
  return List.filter((function (te) {
                  return te[/* status */3] === /* Pending */1;
                }))(tes);
}

function verificationComplete(tes) {
  return List.filter((function (te) {
                  return te[/* status */3] !== /* Pending */1;
                }))(tes);
}

function id(t) {
  return t[/* id */0];
}

function title(t) {
  return t[/* title */1];
}

function description(t) {
  return t[/* description */2];
}

function eventOn(t) {
  return t[/* eventOn */4];
}

function founderName(t) {
  return t[/* founderName */8];
}

function startupName(t) {
  return t[/* startupName */6];
}

function submittedAt(t) {
  return t[/* submittedAt */9];
}

function links(t) {
  return t[/* links */10];
}

function files(t) {
  return t[/* files */11];
}

function status(t) {
  return t[/* status */3];
}

function updateStatus(status, t) {
  return /* record */[
          /* id */t[/* id */0],
          /* title */t[/* title */1],
          /* description */t[/* description */2],
          /* status */status,
          /* eventOn */t[/* eventOn */4],
          /* startupId */t[/* startupId */5],
          /* startupName */t[/* startupName */6],
          /* founderId */t[/* founderId */7],
          /* founderName */t[/* founderName */8],
          /* submittedAt */t[/* submittedAt */9],
          /* links */t[/* links */10],
          /* files */t[/* files */11]
        ];
}

function isVerified(t) {
  var match = t[/* status */3];
  if (typeof match === "number") {
    return false;
  } else {
    return true;
  }
}

exports.title = title;
exports.submittedAt = submittedAt;
exports.eventOn = eventOn;
exports.description = description;
exports.founderName = founderName;
exports.startupName = startupName;
exports.id = id;
exports.links = links;
exports.files = files;
exports.status = status;
exports.forStartupId = forStartupId;
exports.verificationPending = verificationPending;
exports.verificationComplete = verificationComplete;
exports.decode = decode;
exports.updateStatus = updateStatus;
exports.statusString = statusString;
exports.isVerified = isVerified;
exports.gradeString = gradeString;
/* DateTime-ReactTemplate Not a pure module */

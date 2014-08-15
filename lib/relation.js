var EventProxy, Relation, camelize, compile, errFly;

errFly = require('errfly');

EventProxy = require('eventproxy');

Relation = (function() {
  Relation.registry = {};

  Relation.addRelation = function(start, relation, end) {
    var endMulti, endRel, startMulti, startRel, _ref;
    startRel = this.getRelation(start);
    endRel = this.getRelation(end);
    _ref = compile(relation), startMulti = _ref[0], endMulti = _ref[1];
    startRel.addRelation(endRel, startMulti, endMulti);
    endRel.addRelation(startRel, endMulti, startMulti);
    startRel.extendMethods();
    return endRel.extendMethods();
  };

  Relation.getRelation = function(name) {
    if (!this.registry[name]) {
      this.registry[name] = new Relation(this.db, name);
    }
    return this.registry[name];
  };

  function Relation(db, name) {
    var _ref;
    this.name = name;
    this.cname = camelize(this.name);
    this.relations = [];
    this.collection = (_ref = db[this.name]) != null ? _ref : db.bind(this.name);
  }

  Relation.prototype.addRelation = function(oppo, thisMulti, oppoMulti) {
    return this.relations.push({
      oppo: oppo,
      thisMulti: thisMulti,
      oppoMulti: oppoMulti
    });
  };

  Relation.prototype.extendMethods = function() {
    var extendObj, relation, _i, _len, _ref;
    extendObj = {};
    _ref = this.relations;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      relation = _ref[_i];
      if (relation.oppoMulti) {
        extendObj["getAll" + relation.oppo.cname + "s"] = this._getAllFunction(relation.oppo);
      } else {
        extendObj["get" + relation.oppo.cname] = this._getSingleFunction(relation.oppo);
      }
    }
    extendObj["add" + this.cname] = this._getAddFunction();
    return this.collection.bind(extendObj);
  };

  Relation.prototype._getAllFunction = function(to) {
    return (function(_this) {
      return function(selector, option, cb) {
        var wrapper;
        if (typeof option === 'function') {
          cb = option;
          option = {};
        }
        wrapper = errFly(cb);
        return _this.collection.findOne(selector, option, wrapper(function(fromItem) {
          var ep, id, ids, _i, _len, _results;
          ep = new EventProxy();
          ids = fromItem["" + to.name + "Ids"];
          ep.after('getitem', ids.length, function(items) {
            return wrapper.fn(null, items);
          });
          _results = [];
          for (_i = 0, _len = ids.length; _i < _len; _i++) {
            id = ids[_i];
            _results.push(to.collection.findById(id, wrapper(function(toitem) {
              return ep.emit('getitem', toitem);
            })));
          }
          return _results;
        }));
      };
    })(this);
  };

  Relation.prototype._getSingleFunction = function(to) {
    return (function(_this) {
      return function(selector, cb) {
        var wrapper;
        wrapper = errFly(cb);
        return _this.collection.findOne(selector, wrapper(function(fromItem) {
          var toId;
          toId = fromItem["" + to.name + "Id"];
          return to.collection.findById(toId, wrapper(function(toItem) {
            return cb(null, toItem);
          }));
        }));
      };
    })(this);
  };

  Relation.prototype._getAddFunction = function() {
    return (function(_this) {
      return function(_docs, option, cb) {
        var wrapper;
        if (typeof option === 'function') {
          cb = option;
          option = {};
        }
        wrapper = errFly(cb);
        return _this.collection.insert(_docs, option, wrapper(function(docs) {
          var doc, ep, _i, _len, _results;
          ep = new EventProxy();
          ep.after('updatedocs', docs.length, function(docs) {
            if (docs.length === 1) {
              docs = docs[0];
            }
            return wrapper.fn(null, docs);
          });
          _results = [];
          for (_i = 0, _len = docs.length; _i < _len; _i++) {
            doc = docs[_i];
            _results.push((function(doc) {
              var dep, relation, _j, _len1, _ref, _results1;
              dep = new EventProxy();
              dep.after('update', _this.relations.length, function() {
                return ep.emit('updatedocs', doc);
              });
              _ref = _this.relations;
              _results1 = [];
              for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
                relation = _ref[_j];
                _results1.push((function(relation) {
                  var id, update;
                  if (id = doc["" + relation.oppo.name + "Id"]) {
                    if (relation.thisMulti) {
                      update = {
                        $push: {}
                      };
                      update['$push']["" + _this.name + "Ids"] = doc._id;
                    } else {
                      update = {
                        $set: {}
                      };
                      update['$set']["" + _this.name + "Id"] = doc._id;
                    }
                    return relation.oppo.collection.updateById(id, update, wrapper(function(item) {
                      return dep.emit('update', item);
                    }));
                  } else {
                    return dep.emit('update');
                  }
                })(relation));
              }
              return _results1;
            })(doc));
          }
          return _results;
        }));
      };
    })(this);
  };

  return Relation;

})();

compile = function(relation) {
  return relation.split(/\s*->\s*/).map(function(mode) {
    return mode !== "1";
  });
};

camelize = function(s) {
  s = s.toLowerCase();
  return s[0].toUpperCase() + s.slice(1);
};

module.exports = function(db) {
  Relation.db = db;
  return Relation;
};

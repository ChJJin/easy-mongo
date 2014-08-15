errFly = require('errfly');
EventProxy = require('eventproxy');

class Relation
  @registry = {}

  @addRelation = (start, relation, end)->
    startRel = @getRelation(start)
    endRel = @getRelation(end)
    [startMulti, endMulti] = compile(relation)
    startRel.addRelation endRel, startMulti, endMulti
    endRel.addRelation startRel, endMulti, startMulti
    startRel.extendMethods()
    endRel.extendMethods()

  @getRelation = (name)->
    unless @registry[name]
      @registry[name] = new Relation(@db, name)
    @registry[name]

  constructor: (db, @name)->
    @cname = camelize(@name)
    @relations = []
    @collection = db[@name] ? db.bind(@name)

  addRelation: (oppo, thisMulti, oppoMulti)->
    @relations.push {oppo, thisMulti, oppoMulti}

  extendMethods: ()->
    extendObj = {}
    for relation in @relations
      if relation.oppoMulti
        extendObj["getAll#{relation.oppo.cname}s"] = @_getAllFunction(relation.oppo)
      else
        extendObj["get#{relation.oppo.cname}"] = @_getSingleFunction(relation.oppo)

    extendObj["add#{@cname}"] = @_getAddFunction()

    @collection.bind(extendObj)

  _getAllFunction: (to)->
    (selector, option, cb)=>
      if typeof option is 'function'
        cb = option
        option = {}
      wrapper = errFly(cb)
      @collection.findOne selector, option, wrapper (fromItem)->
        ep = new EventProxy()
        ids = fromItem["#{to.name}Ids"]
        ep.after 'getitem', ids.length, (items)->
          wrapper.fn(null, items)
        for id in ids
          to.collection.findById id, wrapper (toitem)->
            ep.emit 'getitem', toitem

  _getSingleFunction: (to)->
    (selector, cb)=>
      wrapper = errFly(cb)
      @collection.findOne selector, wrapper (fromItem)->
        toId = fromItem["#{to.name}Id"]
        to.collection.findById toId, wrapper (toItem)->
          cb null, toItem

  _getAddFunction: ()->
    (_docs, option, cb)=>
      if typeof option is 'function'
        cb = option
        option = {}
      wrapper = errFly(cb)
      @collection.insert _docs, option, wrapper (docs)=>
        ep = new EventProxy()
        ep.after 'updatedocs', docs.length, (docs)->
          if docs.length is 1 then docs = docs[0]
          wrapper.fn(null, docs)
        for doc in docs then do (doc)=>
          dep = new EventProxy()
          dep.after 'update', @relations.length, ()->
            ep.emit('updatedocs', doc)
          for relation in @relations then do (relation)=>
            if id = doc["#{relation.oppo.name}Id"]
              if relation.thisMulti
                update = {$push: {}}
                update['$push']["#{@name}Ids"] = doc._id
              else
                update = {$set: {}}
                update['$set']["#{@name}Id"] = doc._id
              relation.oppo.collection.updateById id, update, wrapper (item)->
                dep.emit 'update', item
            else
              dep.emit 'update'

compile = (relation)->
  relation.split(/\s*->\s*/).map (mode)->
    mode isnt "1"

camelize = (s)->
  s = s.toLowerCase()
  s[0].toUpperCase() + s.slice(1)

module.exports = (db)->
  Relation.db = db
  Relation

should = require('should')
Eventproxy = require('eventproxy')

mongo = require('mongoskin')
dbPath = "mongodb://127.0.0.1:27017/relation_test"
db = mongo.db(dbPath, {safe: true})
Relation = require('../')(db)

describe 'relation', ()->
  before ()->
    Relation.addRelation 'user', '1 -> *', 'topic'
    Relation.addRelation 'topic', '1 -> 1', 'mark'
    Relation.addRelation 'user', '1 -> *', 'mark'
    Relation.addRelation 'user', '1 -> *', 'message'
    Relation.addRelation 'topic', '1 -> *', 'message'

  after (done)->
    ep = new Eventproxy()
    cols = ['user', 'topic', 'mark', 'message']
    ep.after 'dropCol', cols.length, ()->
      db.close(done)
    for col in cols then do (col)->
      if db[col]
        db[col].drop (err, result)->
          ep.emit 'dropCol'
      else
        ep.emit 'dropCol'

  userId = null
  markId = null
  topicId = null

  describe 'call the extend method', ()->
    it 'add one doc', (done)->
      db.user.addUser {name: 'test'}, (err, user)->
        should.not.exist(err)
        user._id.should.be.ok
        user.name.should.equal('test')
        userId = user._id
        done()

    it 'add multi docs', (done)->
      db.mark.addMark [{mark: 'mark1', userId}, {mark: 'mark2', userId}], (err, marks)->
        should.not.exist err
        marks.should.containDeep [{mark: 'mark1', userId}, {mark: 'mark2', userId}]
        markId = marks[0]._id
        db.user.findById userId, (err, user)->
          user.markIds.should.eql marks.map (mark)-> mark._id
          done()

  describe 'add one doc with related docs', ()->
    it 'add one doc with related docs', (done)->
      db.topic.addTopic {userId, content: 'topic1', markId}, (err, topic)->
        topic._id.should.be.ok
        topic.should.containEql {userId, markId, content: 'topic1'}
        db.user.findById userId, (err, user)->
          user.topicIds.should.have.length(1)
          user.topicIds[0].should.eql topic._id
          db.mark.findById markId, (err, mark)->
            mark.topicId.should.eql topic._id
            topicId = topic._id
            done()

    it 'add multi doc with related docs', (done)->
      db.message.addMessage [{userId, meassge: 'message1', topicId}, {userId, meassge: 'message2', topicId}], (err, messages)->
        messages.should.containDeep [
          {userId, meassge: 'message1', topicId}
          {userId, meassge: 'message2', topicId}
        ]
        mids = messages.map (m)-> m._id
        db.user.findById userId, (err, user)->
          user.messageIds.should.eql mids
          db.topic.findById topicId, (err, topic)->
            topic.messageIds.should.eql mids
            done()

  describe 'get docs', ()->
    before (done)->
      db.mark.addMark {mark: 'mark3', topicId}, (err, mark)->
        should.not.exist err
        markId = mark._id
        done()

    it 'one doc', (done)->
      db.topic.getMark {_id: topicId}, (err, mark)->
        should.not.exist err
        mark._id.should.eql markId
        done()

    it 'multi docs', (done)->
      db.topic.getAllMessages topicId, (err, messages)->
        messages.should.containDeep [
          {userId, meassge: 'message1', topicId}
          {userId, meassge: 'message2', topicId}
        ]
        done()

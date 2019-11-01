import 'dart:math';

import 'package:flutter_repository/flutter_repository.dart';
import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';

class Comment {
  int id;
  int tweetId;
  String author;
  String body;

  Comment(this.id, this.tweetId, this.author, this.body);
}

class Tweet {
  int id;
  String author;
  String body;
  Collection<Comment> comments;
  CommentFactory _commentFactory;

  Tweet(this.id, this.author, this.body, this.comments, this._commentFactory);

  Future<void> createComment(String author, String comment) async {
    await comments.add(_commentFactory.create(id, author, body));
  }

  void changeText(String body) {
    this.body = body;
  }

  Future<void> blockAllComments() async {
    await comments.remove(Specification());
  }

  Future<List<Comment>> getAllComments() async {
    return await comments.findAll(Specification());
  }
}

class CommentFactory {
  Random _random;

  CommentFactory(this._random);

  Comment create(int tweetId, String author, String body, {int id}) {
    return Comment(id ?? _random.nextInt(1000), tweetId, author, body);
  }
}

class TweetFactory {
  Random _random;
  Collection<Comment> _comments;
  CommentFactory _commentFactory;

  TweetFactory(this._random, this._comments, this._commentFactory);

  Tweet create(String author, String body, {int id}) {
    final belongToThisTweet = Specification();
    belongToThisTweet.equals('TWEET_ID', id);
    Collection<Comment> tweetsComments = PrivateCollection(belongToThisTweet, _comments);
    return Tweet(id ?? _random.nextInt(1000), author, body, tweetsComments, _commentFactory);
  }
}

class CommentDataSourceServant implements DataSourceServant<Comment> {
  CommentFactory factory;

  @override
  Comment deserialize(Map<String, dynamic> entity) {
    return factory.create(entity['TWEET_ID'], entity['AUTHOR'], entity['BODY'], id: entity['ID']);
  }

  @override
  Iterable<String> get idFieldNames => ['ID'];

  @override
  Map<String, dynamic> serialize(Comment entity) {
    return {
      'ID': entity.id,
      'TWEET_ID': entity.tweetId,
      'AUTHOR': entity.author,
      'BODY': entity.body
    };
  }
}

class TweetDataSourceServant implements DataSourceServant<Tweet> {
  TweetFactory factory;

  @override
  Tweet deserialize(Map<String, dynamic> entity) {
    return factory.create(entity['AUTHOR'], entity['BODY'], id: entity['ID']);
  }

  @override
  Iterable<String> get idFieldNames => ['ID'];

  @override
  Map<String, dynamic> serialize(Tweet entity) {
    return {
      'ID': entity.id,
      'AUTHOR': entity.author,
      'BODY': entity.body
    };
  }
}

void main() async {
  // Initialize application
  final builder = SqfliteDatabaseBuilder();
  builder.instructions(MigrationInstructions(Version(1), [
    MigrationScript('CREATE TABLE TWEETS(ID NUMBER PRIMARY KEY, AUTHOR VARCHAR, BODY VARCHAR)'),
    MigrationScript('CREATE TABLE COMMENTS(ID NUMBER PRIMARY KEY, TWEET_ID NUMBER, AUTHOR VARCHAR, BODY VARCHAR)')
  ]));
  final database = await builder.build();
  final tweetsDataSource = database.table('TWEETS');
  final commentsDataSource = database.table('COMMENTS');
  final tweetServant = TweetDataSourceServant();
  final commentServant = CommentDataSourceServant();
  final tweets = SimpleCollection(tweetsDataSource, tweetServant);
  final comments = SimpleCollection(commentsDataSource, commentServant);
  final random = Random();
  final commentFactory = CommentFactory(random);
  commentServant.factory = commentFactory;
  final tweetFactory = TweetFactory(random, comments, commentFactory);
  tweetServant.factory = tweetFactory;
  // create a tweet with a mistake
  final tweet = tweetFactory.create('Tom', 'How is it going Twitter?');
  tweets.add(tweet);
  // correct a typo in the tweet
  tweet.changeText('How is it going, Twitter?');
  tweets.update(tweet);
  // create a hateful comment
  tweet.createComment('Frank', 'I hate you!');
  // block all the comments
  tweet.blockAllComments();
}
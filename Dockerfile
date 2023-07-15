FROM ruby:3.2.2-bookworm

RUN apt-get update -qq && apt-get install -y nodejs

RUN gem install bundler jekyll

WORKDIR /app

ADD . /app

RUN bundle install

EXPOSE 4000

ENV NAME World

CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]

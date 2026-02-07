FROM ruby:3.2.5-slim-bookworm

# Install nodejs and build dependencies for native extensions
RUN apt-get update -qq \
    && apt-get install -y nodejs build-essential libffi-dev \
    && gem install bundler jekyll \
    # Cleanup to keep the image slim
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Using COPY is preferred over ADD for copying local files
COPY . /app

# Install dependencies specified in your Gemfile
RUN bundle install

EXPOSE 4000

ENV NAME World

CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]

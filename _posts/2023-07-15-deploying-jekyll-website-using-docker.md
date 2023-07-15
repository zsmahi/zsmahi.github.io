---
title: EP03- Deploying a Jekyll Website Using Docker
author: zsmahi
date: 2023-07-15 23:50:00 +0200
categories: [Blogging, Coding]
tags: [jekyll,docker, automation]
pin: true
math: true
mermaid: true
image:
  path: /assets/img/posts/20230715/logo.png
---

## Introduction

Hello folks!

In today's digital age, it's vital to have a strong online presence. While there are many ways to establish one, one straightforward and effective method is through a website. Among the countless tools available for web development, [**Jekyll**](https://jekyllrb.com/) is a static site generator that stands out because of its simplicity and versatility.

Jekyll transforms markdown text into static websites and blogs. It doesn't need databases or updates, making it more secure and faster compared to traditional website platforms. However, setting up a local Jekyll environment can sometimes be a bit of a hassle due to various dependencies.

I'm using Jekyll in this blog by the way :smile:

In this blog post, I'll guide you on how to set up your Jekyll environment inside a Docker container, which allows you to build and run your Jekyll site regardless of your local environment setup.

## Setting up the Dockerfile

First, let's create a Dockerfile that defines our environment:

```dockerfile
# Use an official Ruby runtime as a parent image
FROM ruby:3.2.2-bookworm

# Install Node.js for some js dependencies
RUN apt-get update -qq && apt-get install -y nodejs

# Install Jekyll and Bundler
RUN gem install bundler jekyll

# Set the working directory in the image to /app
WORKDIR /app

# Add the current directory (inside jekyll site folder) contents into the container at /app
ADD . /app

# Install any needed packages specified in Gemfile
RUN bundle install

# Make port 4000 available outside this container
EXPOSE 4000

#optionnal:
ENV NAME World

# Run Jekyll when the container launches
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
```

This Dockerfile first pulls the official Ruby runtime as a parent image. Next, it installs Node.js, Jekyll, and Bundler in the environment. It then sets the working directory to /app and copies the current directory's content into this directory inside the Docker container. Afterward, it installs any packages specified in the Gemfile using bundle install.

Lastly, it exposes port 4000 and instructs Docker to run the Jekyll server when launching the container.

## Building and Running the Docker Image

With the Dockerfile ready, navigate to the directory where it resides and execute the following command to build the Docker image:

```bash
docker build -t your-jekyll-site .
```

Here, **-t your-jekyll-site** assigns a tag to the image, making it easier to reference later. After running this command, Docker will follow the instructions in the Dockerfile to build an image.

To run your Docker image, use the following command:

```bash
docker run --rm -p 4000:4000 your-jekyll-site
```

This command instructs Docker to start a container from the **your-jekyll-site** image. The **-p 4000:4000** flag maps port 4000 inside the Docker container to port 4000 on your host machine, allowing you to access the Jekyll site.

Finally, open a web browser and visit **http://localhost:4000**. Your Jekyll website should be up and running!

## Conclusion

Thanks to Docker, you can have your Jekyll environment up and running within minutes, regardless of your local setup. Not only does this improve the consistency across different development environments, but it also makes it easier for other contributors to get started if you're working as part of a team.

With a Jekyll site running in Docker, you're now ready to start creating awesome content and sharing it with the world :smile:!

I've shared the code seen in this post as a gist

{% gist d1236987ba560f26ef6a1c087ab84540 %}

that's all folks! Keep your blog amazing :grinning:

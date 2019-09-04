FROM jekyll/jekyll:latest
COPY Gemfile /app/Gemfile
WORKDIR /app
RUN touch Gemfile.lock \
   && chmod a+w Gemfile.lock \
   && bundle install
EXPOSE 4000

ENTRYPOINT ["bundle", "exec"]
CMD ["jekyll", "server"]

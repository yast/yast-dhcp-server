FROM yastdevel/ruby:sle12-sp5


RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  yast2-dns-server
COPY . /usr/src/app


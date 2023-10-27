# back-stack

Introducing the BACK Stack


![architecture diagram](./imgs/arch.png)

## Prerequisites
For a local install, you need kind installed and a bash-compatible shell.

## Getting started
- Fork and clone this repo
  ```sh
  gh repo fork opendev-ie/back-stack --clone
  ```
- Create a personal access token [link]
- Configure `./.env` with your personal access token and the repository url
  
  ```properties
  GITHUB_TOKEN=<personal access token>
  REPOSITORY=https://github.com/<path to forked repo>
  ```
- Run the installer
  ```sh
  ./local-install.sh
  ```
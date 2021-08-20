# SantaBot

## Telegram bot for AITA's secret santa 2020

Open folder using Xcode and wait till all packeges will be downloaded.

Choose *Run* scheme in XCode and *My Mac* device and run.

### Useful links

[Swift bot's framework](https://github.com/givip/Telegrammer)

[Article about framework](https://habr.com/ru/post/416023/)

[Deploy on App Engine](https://www.alfianlosari.com/posts/serverless-google-app-engine-with-custom-docker-and-swift-vapor/)

[Deploy on Cloud Run](https://medium.com/@cweinberger/serverless-server-side-swift-using-google-cloud-run-2b314ce74293)

[Connect to database](https://cloud.google.com/sql/docs/mysql/connect-run#java)

#### Deploy command

`gcloud builds submit --tag gcr.io/iappintheair-test/secretsanta --timeout 1h0m0s`

### TODO
* Change admins
* Add timer-reminder for choosing gifts
* Add check for russians gifts (should be only in english)
* Save users' sessions somewhere in cashe instead of `Set` in RAM
* Add empty fields to /info commands as well (else clause in if let)

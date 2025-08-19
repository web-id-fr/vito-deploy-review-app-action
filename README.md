# VitoDeploy Review App GitHub Action

Create/update and deploy a review-application on a [VitoDeploy](https://vitodeploy.com/) instance with GitHub action.

> [!IMPORTANT]  
> This is a GitHub action under development, no release has been made yet. Use with caution!

## Requirements

- [VitoDeploy v3.3.0](https://github.com/vitodeploy/vito/releases/tag/3.3.0)

## Description

This action allows you to automatically create/update and deploy a review-app site on a server managed by a VitoDeploy instance when you open a pull-request or push to a branch.

It works in combination with this other action which removes the review-app site when closing the pull-request:
[web-id-fr/vito-deploy-review-app-clean-action](https://github.com/web-id-fr/vito-deploy-review-app-clean-action)

### Action running process

All steps are done using the VitoDeploy API.

- Create site and database if not done yet. (Auto link the user to the database too)
- Configure repository.
- ~~Obtain Let's Encrypt certificate.~~ (TODO)
- Setup .env file using [stub file](#stub-files).
- Setup deploy script using [stub file](#stub-files).
- Launch deployment.
- ~~Check deployment and display result output.~~ (TODO)

### Optional inputs variables

The action will determine the name of the site (host) and the database if they are not specified (which is **recommended**).

The `host` is based on the branch name (escaping it with only `a-z0-9-` chars) and the `root_domain`.

For example, a `fix-37` branch with `mydomain.tld` root_domain will result in a `fix-37.mydomain.tld` host.

`database_name` is also based on the branch name (escaping it with only `a-z0-9_` chars).

### About stub files
<a name="stub-files"></a>

Stub files must be present on the github workspace of your running workflow before call this action.

You can achieve this using the [checkout action](https://github.com/actions/checkout) on a previous step like this:

```yaml
- name: Checkout stubs file
  uses: actions/checkout@v3
  with:
    sparse-checkout: |
      .github/workflows/.env.stub
      .github/workflows/deploy-script.stub
    sparse-checkout-cone-mode: false
```

#### .env stub file

You must create stub file at the path `.github/workflows/.env.stub` on your repository and checkout the file before running this action (see `env_stub_path` input below).

This file will be used as a template to generate the real content of the .env of the site, by replacing the following strings:

| String                   | Replacement                          |
|--------------------------|--------------------------------------|
| `STUB_HOST`              | Host name of the review-app site.    |
| `STUB_DATABASE_NAME`     | Database name of the review-app.     |
| `STUB_DATABASE_USER`     | Database user of the review-app.     |
| `STUB_DATABASE_PASSWORD` | Database password of the review-app. |

## Deploy script stub file

You must create stub file at the path `.github/workflows/deploy-script.stub` on your repository and checkout the file before running this action (see `deploy_script_stub_path` input below).

This file will be used as a template to generate the real content of the deploy script of the site, by replacing the following strings:

String replacement map:

| String                   | Replacement                          |
|--------------------------|--------------------------------------|
| `STUB_HOST`              | Host name of the review-app site.    |


## Inputs

It is highly recommended that you store all inputs using [GitHub Secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) or variables.

| Input                     | Required | Default                                | Description                                                                                                                                 |
|---------------------------|----------|----------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `api_base_url`            | yes      |                                        | API URL (e.g.: "https://vito.test/api").                                                                                                    |
| `api_token`               | yes      |                                        | API key (with read & write permissions).                                                                                                    |
| `project_id`              | yes      |                                        | Project ID.                                                                                                                                 |
| `server_id`               | yes      |                                        | Server ID.                                                                                                                                  |
| `source_control`          | yes      |                                        | Source Control ID (should be "github" provider).                                                                                            |
| `root_domain`             | no       |                                        | Root domain under which to create review-app site.                                                                                          |
| `host`                    | no       |                                        | Site host of the review-app.<br>The branch name the action is running on will be used to generate it if not defined (recommended).          |
| `prefix_with_pr_number`   | no       | `true`                                 | Use the pull-request number as host and database prefix when host is not manually defined.                                                  |
| `fqdn_prefix`             | no       |                                        | Prefix the whole FQDN (e.g.: "app.")                                                                                                        |
| `type`                    | no       | `php`                                  | Project type of the review-app.                                                                                                             |
| `web_directory`           | no       | `public`                               | Root directory for nginx configuration of the review-app.                                                                                   |
| `isolated`                | no       | `false`                                | Isolate review-app site.                                                                                                                    |
| `php_version`             | no       | `8.3`                                  | PHP version of the review-app site.                                                                                                         |
| `site_setup_timeout`      | no       | `600`                                  | Maximum wait time in seconds for creating site.                                                                                             |
| `create_database`         | no       | `false`                                | Create database for review-app.                                                                                                             |
| `database_setup_timeout`  | no       | `60`                                   | Maximum wait time in seconds for creating database.                                                                                         |
| `create_database_user`    | no       | `false`                                | Create database user for review-app.                                                                                                        |
| `database_user`           | no       | `vito`                                 | Database user of the review-app site (In case creation IS asked).                                                                           |
| `database_user_id`        | no       |                                        | Database user ID of the review-app site (In case creation IS NOT asked).                                                                    |
| `database_password`       | no       |                                        | Database password of the review-app site.<br>Mandatory if `create_database` is set to `true`                                                |
| `database_name`           | no       |                                        | Database name of the review-app site.<br>The branch name the action is running on will be used to generate it if not defined (recommended). |
| `database_name_prefix`    | no       |                                        | Database name prefix, useful for PostgreSQL that does not support digits (PR number) for first chars.                                       |
| `database_charset`        | no       |                                        | Database charset (e.g.: "utf8mb4").                                                                                                         |
| `database_collation`      | no       |                                        | Database collation (e.g.: "utf8mb4_general_ci").                                                                                            |
| `repository`              | no       |                                        | Repository of review-app site.<br>The repository name the action is running on will be used to generate it if not defined.                  |
| `branch`                  | no       |                                        | Git branch to use.<br>The branch name the action is running on will be used to generate it if not defined.                                  |
| `composer`                | no       | `false`                                | Composer install on repository setup.                                                                                                       |
| `env_stub_path`           | no       | `.github/workflows/.env.stub`          | .env stub file path inside git repository.                                                                                                  |
| `deploy_script_stub_path` | no       | `.github/workflows/deploy-script.stub` | Deploy script stub file path inside the git repository.                                                                                     |
| `deployment_timeout`      | no       | `120`                                  | Maximum wait time in seconds for deploying.                                                                                                 |
| `debug`                   | no       | `false`                                | Enable debug output.                                                                                                                        |

## Outputs

| Output             | Description                                                             |
|--------------------|-------------------------------------------------------------------------|
| `host`             | Host of the review-app (generated or forced one in inputs).             |
| `database_user_id` | Database user ID of the review-app (generated or forced one in inputs). |
| `database_name`    | Database name of the review-app (generated or forced one in inputs).    |
| `database_id`      | Database ID of the review-app (if creation was asked).                  |
| `site_id`          | Site ID of the review-app.                                              |

You can easily use those outputs variables to generate a message on your pull-request with this [unsplash/comment-on-pr](https://github.com/unsplash/comment-on-pr) action next.

## Examples

Create or update a review-app on opened pull-requests and comment the PR:

```yml
name: Create Review-App

on:
  pull_request:
    types: [ 'opened', 'reopened', 'synchronize', 'ready_for_review' ]

concurrency: review-app-${{ github.ref }}

jobs:
  review-app:
    runs-on: ubuntu-latest
    name: "Create Review-App"

    if: github.event.pull_request.draft == false

    steps:
      - name: "Checkout required files"
        uses: actions/checkout@v3
        with:
          sparse-checkout: |
            .github/workflows/.env.stub
            .github/workflows/deploy-script.stub
          sparse-checkout-cone-mode: false

      # Optional: If you need to inject secrets in your .env file, you can use this
      - name: "Replace env vars in local env stub file"
        run: |
          sed -i -e "s#SENTRY_LARAVEL_DSN=.*#SENTRY_LARAVEL_DSN='${{ secrets.SENTRY_DSN }}'#" .github/workflows/.env.stub

      - name: "Create Review-App on VitoDeploy"
        id: vito-deploy-review-app
        uses: web-id-fr/vito-deploy-review-app-action@main
        with:
          api_base_url: "https://your-vito-instance.tld/api"
          api_token: ${{ secrets.VITO_REVIEW_APP_SERVER_ID }}
          project_id: "1"
          server_id: "1"
          source_control: "1"
          type: "laravel"
          root_domain: "my-review-apps-root-domain.tld"
          create_database: "true"
          database_charset: "utf8mb4"
          database_collation: "utf8mb4_general_ci"
          create_database_user: "false"
          database_user_id: "1"
          database_password: ${{ secrets.VITO_REVIEW_APP_DATABASE_PASSWORD }}
          deployment_timeout: '1200'
          php_version: "8.3"

      - name: "Add link to the Review-App on the PR comments"
        uses: unsplash/comment-on-pr@v1.3.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          msg: "🚀 Review App for this PR : https://${{ steps.vito-deploy-review-app.outputs.host }}"
```

## Credits

- [Ryan Gilles](https://github.com/rygilles)

## License

TODO

# Setup development environment

- Download your quay.io secret following the steps
  indicated [here](https://consoledot.pages.redhat.com/docs/dev/getting-started/local/environment.html#_get_your_quay_pull_secret).
  And save the content in the `quay-io-pull-secret.yaml` file,
  in the root of this repository.

- Execute the automation to get the environment local
  ready (I have executed it on Fedora 34).

  ```sh
  ./scripts/setup-local.sh
  ```

- To avoid poluting your environment, it creates a
  local virtual python environment at `.venv` directory,
  and it uses nvm to download a version and use that
  environment.
  Activate all the above by:

  ```sh
  source config/prepare-env.sh
  ```

## Frontend poc

see: https://github.com/RedHatInsights/frontend-components/blob/master/packages/docs/pages/ui-onboarding/create-crc-app.md

Running the below:

```sh
cd external
crc-app-start my-app
```

Generate the below tree:

```raw
# tree -I 'node_modules|cache|test_*|dist'
.
├── README.md
├── babel.config.js
├── config
│   └── jest.setup.js
├── deploy
│   └── frontend.yaml
├── fec.config.js
├── jest.config.js
├── package-lock.json
├── package.json
├── spandx.config.js
└── src
    ├── App.js
    ├── App.scss
    ├── AppEntry.js
    ├── Components
    │   └── SampleComponent
    │       ├── sample-component.js
    │       └── sample-component.test.js
    ├── Routes
    │   ├── NoPermissionsPage
    │   │   └── NoPermissionsPage.js
    │   ├── OopsPage
    │   │   └── OopsPage.js
    │   └── SamplePage
    │       └── SamplePage.js
    ├── Routes.js
    ├── bootstrap.js
    ├── entry.js
    └── index.html

9 directories, 21 files
```

Now just do:

```sh
cd my-app
npm install
npm patch:hosts
```

And finally start it by:

```sh
PROXY=yes npm run dev
```

Thoughts:

- How to set up the routes to go inside the minikube services
  deployed by bonfire; is the configuration about routes indicated
  below the way to set it up?
  see: https://github.com/RedHatInsights/frontend-components/tree/master/packages/config#useproxy
- How to inject frontend parts from or applications from
  local path? Is it possible? I am thinking about inject
  a local ImageBuilder frontend, from some local change
  in the repo.
- The generated above seems to be based on Javascript.
  Is it possible to get the same for TypeScript?
  I am not familiar with TypeScript further than an
  on-line basic course several years ago.

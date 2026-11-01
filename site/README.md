# DriveIt account deletion site

This folder is a plain, self-contained GitHub Pages artifact. It contains no build step, tracking code, form backend, third-party assets, or user-submitted data. Pushing this branch does not publish it.

## Free hosting conditions

GitHub Pages is available on GitHub Free when the repository is public. The default project URL uses `https://<owner>.github.io/<repository>/`; no custom domain is needed. Pages content is public. Before publication, confirm that the repository may be public and obtain separate explicit approval to publish this account deletion resource.

## Deliberate publication gate

The repository workflow `.github/workflows/publish-account-deletion-site.yml` only runs from a manual `workflow_dispatch` and requires `confirm_publication=true`. It is not triggered by push. Before the first dispatch, a repository administrator must enable Pages with **GitHub Actions** as the source. Do not dispatch until the operator process and privacy text have been approved. A successful dispatch makes the resource public.

The artifact root is this directory. Its request route is `account-deletion/` and its privacy draft route is `privacy/`. Update Play Console's web resource URL only after publication and a real external functional check. The current repository's Pages eligibility, visibility, settings, URL ownership and deployment were not changed or verified here.

## Local checks

From the repository root run:

```powershell
C:\Users\PC\.deno\bin\deno.exe test --allow-read=site,.github/workflows site/tests/deletion_pages_test.ts
```

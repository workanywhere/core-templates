# Usage

```shell
rails _7.2.0_ new my-app-1 \
  --database=postgresql \
  --skip-test \
  --skip-jbuilder \
  --asset-pipeline=propshaft \
  --template https://raw.githubusercontent.com/workanywhere/core-templates/main/template.rb
```

If you are working on diffent branch the script will work as well:

```shell
https://raw.githubusercontent.com/workanywhere/core-templates/develop/template.rb
```
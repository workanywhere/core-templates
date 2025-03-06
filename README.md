# Usage

```
Ruby 3.4.2
Rails 8.0.1
```

```shell
rails _8.0.1_ new my-app-1 \
  --database=postgresql \
  --skip-test \
  --skip-jbuilder \
  --template https://raw.githubusercontent.com/workanywhere/core-templates/main/template.rb
```

If you are working on diffent branch the script will work as well:

```shell
https://raw.githubusercontent.com/workanywhere/core-templates/develop/template.rb
```

```
cd my-app-1
```

```
PORT=3010 ./bin/dev
```

```
open http://localhost:3010/posts
```


# punff

personal site. [punff.port0.org](https://punff.port0.org)

## structure

```
new.sh              — post a new card
build.sh            — assemble index.html from month files
template/
  header.html       — css lives here
  footer.html       — js lives here
months/             — one file per month, gitignored (personal content)
```

## posting

```bash
./new.sh
```

## deploy

```bash
git pull && bash build.sh
```

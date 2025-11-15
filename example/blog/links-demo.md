```@@frontmatter
{
  "title": "Links Demo",
  "description": "Demonstration of different types of links in markdown.",
  "date": "2025-11-01"
}
```

# Links Demo

## External Link
This is an example of link that goes outside the site: [Google](https://www.google.com)

## Internal Relative to current folder Link
Relative to current folder link: [Inline Style Examples](./inline_styles.html)

## Internal but root link
Root link: [Project](/project)

## Image Links
{{ @@grid_start 2 }}

![External](https://placehold.co/600x300)
![Internal Root](/__assets/gen_image.png)
![Internal Relative](../__assets/gen_image.png)

{{ @@grid_end }}
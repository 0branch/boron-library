STYLE = css/lsr-doc.css
PDOPT = -s -N -f markdown
# --toc --self-contained

all: sup.html

sup.html: sup.md $(STYLE)
	pandoc $(PDOPT) --css=$(STYLE) -o $@ $<

publish: sup.html
	scp $< $(URLAN_HTDOCS)

clean:
	rm sup.html

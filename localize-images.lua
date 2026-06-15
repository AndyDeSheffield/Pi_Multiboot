-- Rewrites GitHub image URLs to local miniweb server URLs
-- Example output: http://127.0.0.1/pi_imager.8.jpg

local base_url = "http://127.0.0.1/"

function Image(img)
  local url = img.src
  if url:match("githubusercontent%.com") or url:match("github%.com") then
    local filename = url:match("([^/%?]+)$")
    img.src = base_url .. filename
  end
  return img
end

function RawInline(el)
  if el.format == "html" then
    local new = el.text:gsub(
      'src="https://github.com/[^"]+/documentation_images/([^"?]+)%?raw=true"',
      'src="' .. base_url .. '%1"'
    )
    return pandoc.RawInline("html", new)
  end
end

function RawBlock(el)
  if el.format == "html" then
    local new = el.text:gsub(
      'src="https://github.com/[^"]+/documentation_images/([^"?]+)%?raw=true"',
      'src="' .. base_url .. '%1"'
    )
    return pandoc.RawBlock("html", new)
  end
end

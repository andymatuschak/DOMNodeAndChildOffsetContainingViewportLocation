###
Finds the deepest possible DOMRange-style containing DOMNode and offset
within a specified node which contains a specified viewport-relative
location, suitable for passing to DOMRange's setStart and setEnd funtions.
You can use this to find the character in a text node at a particular
location in pixels.

startNode - The search will be conducted within this DOMNode's subtree.
clientX   - The viewport-relative location (a la CSSOM View) to search for.
clientY   --^

Examples
  # HTML:
  <div id="mydiv">
      Some <strong>text</strong> and an image: <img src="a.jpg" />
  </div>

  # CoffeeScript:
  $("#mydiv").mousemove( (event) ->
      window.DOMNodeAndChildOffsetContainingViewportLocation this, event.clientX,
                                                             event.clientY
      # => [theTextNodeContaining'Some ', 3] (if your cursor is over the 'e')
      # => [theTextNodeContaining'text', 2] (if your cursor is over the 'x')
      # => [this, 3] (if your cursor is over the image)
      # => [null, 0] (if your cursor isn't within #myDiv)
  )
    
Returns a two-element array. At index 0 will be the deepest node containing
  the DOMRange which contains the input location. At index 1 will be the offset
  within that container node of the child element (or, in the case of a text
  node, the character) whose bounding rect contains that location.

Raises if startNode is undefined or null.
Raises if the browser does not support DOMRange.getClientRects().

###
@DOMNodeAndChildOffsetContainingViewportLocation = (startNode, clientX, clientY) ->
    throw "startNode must be defined and non-null" unless startNode?
    
    testRange = document.createRange()
    throw "This browser does not support DOMRange.getClientRects()" unless testRange.getClientRects?
    testRange.setStart startNode, 0
    testRange.setEnd startNode, 1
    
    isCharacterData = (node) ->
        switch node.nodeType
            when Node.TEXT_NODE, Node.COMMENT_NODE, Node.CDATA_SECTION_NODE then true
            else false
        
    recursiveHelper = (node) ->
        regionContainsInputPoint = (node, startOffset, endOffset) ->
            testRange.setStart node, startOffset
            testRange.setEnd node, endOffset
            rectContainsPoint = (rect) -> clientX >= rect.left && clientY >= rect.top && clientX <= rect.right && clientY <= rect.bottom
            true in (rectContainsPoint rect for rect in testRange.getClientRects())
        
        # Do a binary search to find the offset which contains the location, recursing to child nodes.
        # For a charater data node, we'll find the offset within this node's content.
        low = 0
        high = if isCharacterData node then node.length else node.childNodes.length
        return [null, 0] if low == high
        
        while low <= high
            mid = low + Math.floor((high - low) / 2)
            
            # Base case of the recursion: a single-width range.
            if high - low <= 1
                if regionContainsInputPoint node, low, high then break else return [null, 0]
            
            # Recurse to children:
            if regionContainsInputPoint node, low, mid
                high = mid
            else if regionContainsInputPoint node, mid, high
                low = mid
            else
                return [null, 0]
                
        # We've finished the binary search. If we're here, then we found some single-width range which contains this location.
        
        # So if we're a text-like node, no need to recurse further.
        return [node, low] if isCharacterData node 
        
        # Otherwise, see if the child node can give us a more specific location.
        [hitNode, hitNodeOffset] = recursiveHelper node.childNodes[low]
        
        if hitNode then return [hitNode, hitNodeOffset] else return [node, low]
    
    result = recursiveHelper startNode
    testRange.detach()
    result
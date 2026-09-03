return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  sv.settings.welcomed = nil

  Verdant.Visibility.set("graph", false)
  Verdant.Graph.toggle()
  ok(VerdantGraphWindowWelcome._hidden == false, "first open must greet")
  Verdant.Graph.on_welcome_ok()
  ok(VerdantGraphWindowWelcome._hidden == true, "got-it must dismiss the card")
  ok(sv.settings.welcomed == true, "dismissal must persist")
  Verdant.Graph.toggle()
  Verdant.Graph.toggle()
  ok(VerdantGraphWindowWelcome._hidden == true, "the card shows exactly once")
  Verdant.Graph.toggle()

  ok((VerdantGraphWindowTitleLabel._text or ""):find("your output only") ~= nil,
     "the attribution line must live in the title")

  Verdant.Visibility.set("graph", true)
  local vl = VerdantGraphWindowViewLabel
  while vl._text ~= "OHEAL" do Verdant.Graph.next_view() end
  vl._onOnMouseEnter(vl)
  ok((H.last_tooltip or ""):find("full") ~= nil,
     "the view tooltip must explain OHEAL, got " .. tostring(H.last_tooltip))
  vl._onOnMouseExit(vl)
  ok(H.last_tooltip == nil, "leaving must clear the tooltip")
  while vl._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Visibility.set("graph", false)
end

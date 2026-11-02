local _, addon = ...
local CF = addon.CF

-- Presentation only: the existing options controls retain their callbacks.
local ART = "Interface\\AddOns\\CursiveForever\\Media\\OptionsGrimoire.tga"
local CONTROLS = "Interface\\AddOns\\CursiveForever\\Media\\GrimoireControls.tga"
local SELECTOR = "Interface\\AddOns\\CursiveForever\\Media\\GrimoireDesignSelector.tga"
local SIGNATURE = "Interface\\AddOns\\CursiveForever\\Media\\GrimoireSignature.tga"
local BOOK_W, BOOK_H = 1360, 1020
local LEFT, TOP, RIGHT, COLUMN = 325, 432, 395, 310
-- The complete silhouette is padded to 1536 x 1152 inside a 2048-square texture.
local ART_SCALE = BOOK_W/1536
local SPINE, LEAF_WIDTH, LEAF_TOP, LEAF_BOTTOM = 674, 396, 340, 704
local TURN_SECONDS, STRIPS = 0.44, 32
local SEAL_X, SEAL_Y, SEAL_W, SEAL_H = 728, 657, 302, 46
local SEAL_U1, SEAL_U2, SEAL_V1, SEAL_V2 = 0.01, 0.99, 0.20, 0.50

local function Place(object, x, y, width, height)
    object:ClearAllPoints()
    object:SetPoint("TOPLEFT", x, -y)
    if width and height then object:SetSize(width,height) end
end

local function Ink(text, heading)
    text:SetTextColor(heading and 0.07 or 0.10,heading and 0.04 or 0.06,0.025,1)
    text:SetShadowOffset(0,0)
    -- Existing help strings contain gold color escapes intended for dark panels.
    local value=text:GetText()
    if value then text:SetText(value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")) end
end

local function SetVisible(object, visible)
    if visible then object:Show() else object:Hide() end
end

local function Mix(a,b,amount)
    return a+(b-a)*amount
end

function CF.AttachGrimoire(f, bindings)
    local db=bindings.db
    local index={}
    for i,page in ipairs(f.optionPages) do index[page.id]=i end
    local function Full() return db.optionsDesign~="minimal" end

    local art=f:CreateTexture(nil,"BACKGROUND",nil,-8)
    art:SetTexture(ART); art:SetAllPoints(); art:SetTexCoord(0,0.75,0,0.5625); art:Hide()
    f.grimoireArt=art

    local signatureFrame=CreateFrame("Frame",nil,f)
    -- The resting right page lies beneath the moving sheet, just like its title.
    signatureFrame:SetAllPoints(); signatureFrame:SetFrameLevel(f:GetFrameLevel()+30)
    local signature=signatureFrame:CreateTexture(nil,"OVERLAY")
    signature:SetTexture(SIGNATURE)
    signature:SetTexCoord(SEAL_U1,SEAL_U2,SEAL_V1,SEAL_V2)
    Place(signature,SEAL_X,SEAL_Y,SEAL_W,SEAL_H)
    signatureFrame:Hide(); f.grimoireSignature=signature
    f.closeButton:SetFrameLevel(f:GetFrameLevel()+70)

    local design=CreateFrame("Frame",nil,f.pages.general,"BackdropTemplate")
    design:SetFrameLevel(f:GetFrameLevel()+60)
    local designTitle=design:CreateFontString(nil,"OVERLAY","GameFontNormal")
    designTitle:SetJustifyH("LEFT")
    local designHelp=design:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    designHelp:SetJustifyH("LEFT"); designHelp:SetJustifyV("TOP"); designHelp:SetWordWrap(true)
    local designArt=design:CreateTexture(nil,"BACKGROUND")
    designArt:SetTexture(SELECTOR); designArt:SetAllPoints(); designArt:Hide()
    f.designChoices={}
    for i,name in ipairs({"FULL","minimal"}) do
        local button=CreateFrame("CheckButton",nil,design,"UIRadioButtonTemplate")
        button:SetSize(20,20)
        if button.Text then button.Text:Hide() end
        button.cfNativeRegions={}
        for _,region in ipairs({button:GetRegions()}) do
            button.cfNativeRegions[#button.cfNativeRegions+1]={region,region:GetAlpha()}
        end
        button.bookFace=button:CreateTexture(nil,"BACKGROUND")
        button.bookFace:SetTexture(SELECTOR); button.bookFace:SetAllPoints(); button.bookFace:Hide()
        button.bookFace:SetTexCoord(0.08,0.94,i==1 and 0.49 or 0.725,i==1 and 0.675 or 0.91)
        button.label=button:CreateFontString(nil,"OVERLAY","GameFontNormal")
        button.label:SetPoint("LEFT",button,"RIGHT",4,0)
        button.label:SetText(name); button.label:SetJustifyH("LEFT"); button.label:SetWidth(90)
        button:SetHitRectInsets(0,-90,0,0)
        button.CFRefreshLook=function(hover)
            if not button.cfBookDesign then button.label:SetTextColor(1,0.82,0); return end
            local active=db.optionsDesign==name
            local tint=(active or hover) and 1 or 0.60
            button.bookFace:SetVertexColor(tint,tint,tint,1)
            if active then button.label:SetTextColor(0.70,1,0.38)
            elseif hover then button.label:SetTextColor(1,0.94,0.72)
            else button.label:SetTextColor(0.84,0.76,0.58) end
        end
        button:SetScript("OnClick",function() f.CFSetDesign(name) end)
        button:SetScript("OnEnter",function(self)
            self.CFRefreshLook(true)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(CF.T("OPTIONS_DESIGN"),1,0.82,0.35)
            GameTooltip:AddLine(CF.T("OPTIONS_DESIGN_TIP"),1,1,1,true); GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function(self) self.CFRefreshLook(false); GameTooltip:Hide() end)
        f.designChoices[name]=button
    end
    f.designGroup=design
    f.cfDesignHelp,f.cfDesignTitle=designHelp,designTitle
    -- The compact parchment layout keeps the archive explanation on its launcher.
    local monitor=f.controls.monitor
    local monitorEnter,monitorLeave=monitor:GetScript("OnEnter"),monitor:GetScript("OnLeave")
    monitor:SetScript("OnEnter",function(self)
        if monitorEnter then monitorEnter(self) end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(CF.T("OPTIONS_MONITOR"),1,0.82,0.35)
        GameTooltip:AddLine(CF.T("OPTIONS_ARCHIVE_HELP"),1,1,1,true); GameTooltip:Show()
    end)
    monitor:SetScript("OnLeave",function(self) if monitorLeave then monitorLeave(self) end; GameTooltip:Hide() end)

    -- Reusable animation layer. It has no idle OnUpdate and never records data.
    local turn=CreateFrame("Frame",nil,f)
    turn:SetAllPoints(); turn:SetFrameLevel(f:GetFrameLevel()+35); turn:EnableMouse(true); turn:Hide()
    turn.strips,turn.shadows,turn.signatures={},{},{}
    local sealStart,sealEnd=(SEAL_X-SPINE)/LEAF_WIDTH,(SEAL_X+SEAL_W-SPINE)/LEAF_WIDTH
    local sealTop,sealBottom=(SEAL_Y-LEAF_TOP)/(LEAF_BOTTOM-LEAF_TOP),(SEAL_Y+SEAL_H-LEAF_TOP)/(LEAF_BOTTOM-LEAF_TOP)
    for i=1,STRIPS do
        -- Outer paper segments sit in front of inner segments, including their
        -- ink. This also prevents front-face ink showing through a curled back.
        local segment=CreateFrame("Frame",nil,turn)
        segment:SetAllPoints(); segment:SetFrameLevel(turn:GetFrameLevel()+i)
        local texture=segment:CreateTexture(nil,"ARTWORK")
        texture:SetTexture(ART)
        -- The artwork retains alpha around the character. Paper samples must
        -- overwrite the page beneath even if their source alpha is below 255.
        texture:SetBlendMode("DISABLE"); turn.strips[i]=texture
        -- Clip the inscription to the existing paper segments, including its
        -- partial first/last segment. Reuse all textures for subsequent turns.
        local start,finish=(i-1)/STRIPS,i/STRIPS
        local first,last=math.max(start,sealStart),math.min(finish,sealEnd)
        if last>first then
            local ink=segment:CreateTexture(nil,"OVERLAY")
            ink:SetTexture(SIGNATURE); ink:Hide()
            turn.signatures[i]={texture=ink,first=(first-start)/(finish-start),last=(last-start)/(finish-start),
                u1=Mix(SEAL_U1,SEAL_U2,(first-sealStart)/(sealEnd-sealStart)),
                u2=Mix(SEAL_U1,SEAL_U2,(last-sealStart)/(sealEnd-sealStart))}
        end
    end
    for i=1,8 do turn.shadows[i]=turn:CreateTexture(nil,"BACKGROUND") end
    f.pageTurnLayer=turn

    local function Quad(texture,x1,top1,bottom1,x2,top2,bottom2,u1,u2,v1,v2)
        if x1>x2 then x1,x2,top1,top2,bottom1,bottom2,u1,u2=x2,x1,top2,top1,bottom2,bottom1,u2,u1 end
        local top,bottom=math.min(top1,top2),math.max(bottom1,bottom2)
        local width=math.max(0.25,x2-x1)
        Place(texture,x1,top,width,bottom-top)
        texture:SetTexCoord(u1,u2,v1,v2)
        if texture.SetVertexOffset then
            texture:SetVertexOffset(UPPER_LEFT_VERTEX or 1,0,top-top1)
            texture:SetVertexOffset(LOWER_LEFT_VERTEX or 2,0,bottom-bottom1)
            texture:SetVertexOffset(UPPER_RIGHT_VERTEX or 3,0,top-top2)
            texture:SetVertexOffset(LOWER_RIGHT_VERTEX or 4,0,bottom-bottom2)
        end
    end

    local function SealEdge(x1,t1,b1,x2,t2,b2,amount)
        local top,bottom=Mix(t1,t2,amount),Mix(b1,b2,amount)
        return Mix(x1,x2,amount),Mix(top,bottom,sealTop),Mix(top,bottom,sealBottom)
    end

    local function RenderTurn(progress,direction)
        local eased=progress*progress*(3-2*progress)
        local angle=math.pi*eased
        local lift=math.sin(angle)
        local function Edge(u)
            local bend=0.28*lift*math.sin(math.pi*u)
            local x=SPINE+direction*LEAF_WIDTH*u*math.cos(angle-bend)
            return x,LEAF_TOP-24*lift*u,LEAF_BOTTOM+14*lift*u
        end
        for i,texture in ipairs(turn.strips) do
            local u1,u2=(i-1)/STRIPS,i/STRIPS
            local x1,t1,b1=Edge(u1)
            local x2,t2,b2=Edge(u2)
            -- Each segment has two printed faces. Its projected orientation
            -- chooses the visible face even while the curved fold straddles
            -- the edge-on position: right page on one face, left on the other.
            local face=x2>=x1 and 1 or -1
            local s1=(SPINE+face*LEAF_WIDTH*u1)/ART_SCALE/2048
            local s2=(SPINE+face*LEAF_WIDTH*u2)/ART_SCALE/2048
            Quad(texture,x1,t1,b1,x2,t2,b2,s1,s2,LEAF_TOP/ART_SCALE/2048,LEAF_BOTTOM/ART_SCALE/2048)
            local shade=0.68+0.32*math.abs(math.cos(angle-0.28*lift*math.sin(math.pi*(u1+u2)/2)))
            -- Solid paper must cover the underlying title and controls all the
            -- way to rest. Only native option controls fade, never the sheet.
            texture:SetVertexColor(shade,shade,shade,1)
            local seal=turn.signatures[i]
            if seal then
                -- The inscription is printed only on the right-page face.
                -- It turns away forward and comes into view on backward turns.
                local sourcePage = turn.state and (direction==1 and turn.state.from or turn.state.target) or f.activePage
                SetVisible(seal.texture,face==1 and sourcePage=="help")
                if face==1 and sourcePage=="help" then
                    local sx1,st1,sb1=SealEdge(x1,t1,b1,x2,t2,b2,seal.first)
                    local sx2,st2,sb2=SealEdge(x1,t1,b1,x2,t2,b2,seal.last)
                    Quad(seal.texture,sx1,st1,sb1,sx2,st2,sb2,seal.u1,seal.u2,SEAL_V1,SEAL_V2)
                    seal.texture:SetVertexColor(shade,shade,shade,1)
                end
            end
        end
        for i,shadow in ipairs(turn.shadows) do
            local side=math.cos(angle)>=0 and 1 or -1
            Place(shadow,SPINE+direction*side*(i-1)*24-(direction*side<0 and 24 or 0),LEAF_TOP,24,LEAF_BOTTOM-LEAF_TOP)
            shadow:SetColorTexture(0.12,0.05,0.01,lift*0.19*(1-i/9)^2)
        end
        local page=f.pages[f.activePage]
        if page then page:SetAlpha(progress<0.5 and math.max(0,1-progress*3) or math.max(0,(progress-0.65)/0.35)) end
    end
    f.CFRenderPageTurn=RenderTurn

    local function RestoreInputs()
        if turn.inputStates then
            for control,enabled in pairs(turn.inputStates) do control:SetEnabled(enabled) end
            turn.inputStates=nil
        end
    end
    f.CFCancelPageTurn=function(commit)
        local target=commit and (turn.queued or (turn.state and turn.state.target))
        turn:SetScript("OnUpdate",nil); turn:Hide(); turn.state=nil; turn.queued=nil
        for _,seal in pairs(turn.signatures) do seal.texture:Hide() end
        RestoreInputs()
        if target then f.CFSelectPage(target) end
        for _,page in pairs(f.pages) do page:SetAlpha(1) end
    end
    f.CFRequestPage=function(id)
        if not index[id] then return end
        if turn.state then turn.queued=id; return end
        if id==f.activePage then return end
        if not Full() or f.cfJaina or not f:IsShown() then f.CFSelectPage(id); return end
        local direction=index[id]>index[f.activePage] and 1 or -1
        turn.state={target=id,from=f.activePage,direction=direction,elapsed=0,switched=false}
        turn.inputStates={}
        for _,control in pairs(f.controls) do
            if control.IsEnabled and control.SetEnabled then
                turn.inputStates[control]=control:IsEnabled(); control:SetEnabled(false)
            end
        end
        turn:Show(); RenderTurn(0,direction)
        turn:SetScript("OnUpdate",function(self,elapsed)
            local state=self.state
            if not state then return end
            state.elapsed=state.elapsed+elapsed
            local progress=math.min(1,state.elapsed/TURN_SECONDS)
            if progress>=0.5 and not state.switched then
                state.switched=true; f.CFSelectPage(state.target)
            end
            RenderTurn(progress,state.direction)
            if progress>=1 then
                local queued=self.queued
                f.CFCancelPageTurn(false); f.CFSelectPage(state.target)
                if queued and queued~=f.activePage then f.CFRequestPage(queued) end
            end
        end)
    end

    local oldTabs=f.CFRefreshTabs
    f.CFRefreshTabs=function()
        oldTabs()
        SetVisible(signatureFrame,Full() and f.activePage=="help")
        if Full() then
            for id,tab in pairs(f.tabs) do
                local selected=id==f.activePage
                tab:SetBackdrop(nil)
                tab.cfLabel:ClearAllPoints(); tab.cfLabel:SetPoint("CENTER",tab,"CENTER",-14,0)
                tab.cfLabel:SetTextColor(selected and 0.8 or 0.93,selected and 1 or 0.78,selected and 0.42 or 0.50,1)
                tab.cfSelectedLine:SetColorTexture(0.47,0.85,0.18,0.8)
            end
        end
    end

    local function SkinAction(button,full)
        if not button.cfBookArt then
            button.cfBaseBackdrop=button:GetBackdrop()
            button.cfBaseBackdropColor={button:GetBackdropColor()}
            button.cfBaseBorderColor={button:GetBackdropBorderColor()}
            button.cfBaseLabelColor={button.cfLabel:GetTextColor()}
            local texture=button:CreateTexture(nil,"BACKGROUND")
            texture:SetTexture(CONTROLS); texture:SetTexCoord(0.026,0.978,0.339,0.608)
            texture:SetAllPoints(); texture:Hide(); button.cfBookArt=texture
            local enter,leave=button:GetScript("OnEnter"),button:GetScript("OnLeave")
            button:SetScript("OnEnter",function(self)
                if enter then enter(self) end
                if f.cfGrimoire then texture:SetVertexColor(1,1,0.85); self.cfLabel:SetTextColor(1,0.93,0.66) end
            end)
            button:SetScript("OnLeave",function(self)
                if leave then leave(self) end
                if self.cfGrimoireSkin then self.cfGrimoireSkin() end
            end)
        end
        if full then
            button.cfGrimoireSkin=function()
                button:SetBackdrop(nil); button.cfDecorIcon:Hide(); button.cfBookArt:Show()
                button.cfBookArt:SetVertexColor(1,1,1)
                button.cfLabel:ClearAllPoints(); button.cfLabel:SetPoint("CENTER")
                button.cfLabel:SetTextColor(0.96,0.81,0.56,1)
            end
            button.cfGrimoireSkin()
        else
            button.cfGrimoireSkin=nil; button.cfBookArt:Hide(); button:SetBackdrop(button.cfBaseBackdrop)
            -- Recreating a backdrop resets its tint to white. Restore the
            -- minimal appearance immediately, without waiting for mouse hover.
            button:SetBackdropColor(unpack(button.cfBaseBackdropColor))
            button:SetBackdropBorderColor(unpack(button.cfBaseBorderColor))
            button.cfLabel:SetTextColor(unpack(button.cfBaseLabelColor))
        end
    end

    local function SkinSlider(slider,full)
        do
            -- All book rails need their limit labels below the ornate end caps.
            -- Keep the original anchors for the minimal design and leave the
            -- native label anchors when returning to minimal.
            if not slider.cfMoPLabelAnchors then
                slider.cfMoPLabelAnchors={}
                for _,key in ipairs({"Low","High"}) do
                    if slider[key] then slider.cfMoPLabelAnchors[key]={slider[key]:GetPoint(1)} end
                end
            end
            for key,point in pairs(slider.cfMoPLabelAnchors) do
                local label=slider[key]
                label:ClearAllPoints()
                if full then
                    label:SetPoint(key=="Low" and "TOPLEFT" or "TOPRIGHT",slider,
                        key=="Low" and "BOTTOMLEFT" or "BOTTOMRIGHT",0,-9)
                elseif point[1] then label:SetPoint(unpack(point)) end
            end
        end
        if not slider.cfBookRail then
            slider.cfNativeRegions={}
            if slider.GetRegions then
                for _,region in ipairs({slider:GetRegions()}) do
                    if region~=slider.Low and region~=slider.High and region~=slider.Text and region~=slider:GetThumbTexture() then
                        slider.cfNativeRegions[#slider.cfNativeRegions+1]={object=region,alpha=region:GetAlpha()}
                    end
                end
            end
            slider.cfBaseBackdrop=slider.GetBackdrop and slider:GetBackdrop()
            local thumb=slider:GetThumbTexture()
            slider.cfBaseThumb={texture=thumb:GetTexture(),width=thumb:GetWidth(),height=thumb:GetHeight(),coords={thumb:GetTexCoord()}}
            local rail=slider:CreateTexture(nil,"ARTWORK")
            rail:SetTexture(CONTROLS); rail:SetTexCoord(0.012,0.988,0.143,0.261)
            rail:SetPoint("TOPLEFT",-18,3); rail:SetPoint("BOTTOMRIGHT",18,-3)
            slider.cfBookRail=rail
            local fill=slider:CreateTexture(nil,"ARTWORK",nil,1)
            fill:SetColorTexture(0.22,0.59,0.045,0.67); fill:SetPoint("LEFT",2,0); fill:SetHeight(4)
            slider.cfBookFill=fill
            local callback=slider:GetScript("OnValueChanged")
            slider:SetScript("OnValueChanged",function(self,value,...)
                if callback then callback(self,value,...) end
                if f.cfGrimoire and not f.cfJaina then Ink(self.cfCaption) end
                local low,high=self:GetMinMaxValues()
                fill:SetWidth(math.max(0.1,(self:GetWidth()-4)*math.max(0,math.min(1,(value-low)/(high-low)))))
            end)
        end
        for _,entry in ipairs(slider.cfNativeRegions) do entry.object:SetAlpha(full and 0 or entry.alpha) end
        if slider.SetBackdrop then
            if full then slider:SetBackdrop(nil) else slider:SetBackdrop(slider.cfBaseBackdrop) end
        end
        local thumb=slider:GetThumbTexture()
        if full then
            thumb:SetTexture(CONTROLS); thumb:SetTexCoord(0.365,0.635,0.629,0.968); thumb:SetSize(19,25)
            thumb:SetDrawLayer("OVERLAY",2)
            if slider.Low then Ink(slider.Low) end
            if slider.High then Ink(slider.High) end
        else
            local saved=slider.cfBaseThumb
            thumb:SetTexture(saved.texture); thumb:SetTexCoord(unpack(saved.coords)); thumb:SetSize(saved.width,saved.height)
            if slider.Low then slider.Low:SetTextColor(1,1,1) end
            if slider.High then slider.High:SetTextColor(1,1,1) end
        end
        SetVisible(slider.cfBookRail,full); SetVisible(slider.cfBookFill,full)
        local low,high=slider:GetMinMaxValues()
        slider.cfBookFill:SetWidth(math.max(0.1,(slider:GetWidth()-4)*math.max(0,math.min(1,(slider:GetValue()-low)/(high-low)))))
    end

    local function Label(key,x,y,width,height)
        local label=f.optionLabels[key]
        if label then Place(label,x,y,width or COLUMN,height or 24) end
    end
    local function Control(key,x,y,width,height)
        local control=f.controls[key]
        local kind=control.cfOptionsLayout.kind
        Place(control,x,y,kind=="checkbox" and 26 or (width or COLUMN),height or (kind=="checkbox" and 26 or 32))
        if kind=="checkbox" then
            control.Text:SetWidth((width or COLUMN)-34)
            control:SetHitRectInsets(0,-((width or COLUMN)-26),0,0)
        elseif kind=="action" then control.cfLabel:SetWidth((width or COLUMN)-38) end
    end
    local function Slider(key,x,y)
        local slider=f.controls[key]
        Place(slider.cfCaption,x,y,COLUMN,20)
        local inset=(key=="scale" or key=="trackerWidth" or key=="trackerHeight") and 32 or 16
        Control(key,x+inset,y+28,COLUMN-inset*2,18)
    end

    f.CFRefreshPresentation=function()
        f.CFCancelPageTurn(true)
        local full=Full()
        db.optionsDesign=full and "FULL" or "minimal"
        f.cfGrimoire=full
        f.cfJaina=full and CF.OptionsArtwork and CF.OptionsArtwork.Resolve(db)=="jaina" or false
        f:SetSize(full and BOOK_W or 760,full and BOOK_H or 620)
        SetVisible(art,full); SetVisible(f.classicBackdrop,not full); SetVisible(signatureFrame,full and f.activePage=="help")
        for _,object in ipairs(f.optionNodes) do
            local layout=object.cfOptionsLayout
            Place(object,layout.x,layout.y,layout.kind=="checkbox" and 26 or layout.width,layout.height)
            object:Show()
            if layout.kind=="heading" or layout.kind=="text" then
                if object.cfOptionsKey then object:SetText(CF.T(object.cfOptionsKey)) end
                if full then Ink(object,layout.kind=="heading")
                else object:SetTextColor(layout.kind=="heading" and 0.87 or 0.78,layout.kind=="heading" and 0.74 or 0.76,layout.kind=="heading" and 0.38 or 0.70); object:SetShadowOffset(1,-1) end
            elseif layout.kind=="action" then
                object.cfLabel:SetWidth(layout.width-48); SkinAction(object,full)
            elseif layout.kind=="checkbox" then
                object.Text:SetWidth(layout.width-34); object:SetHitRectInsets(0,-(layout.width-26),0,0)
                if full then Ink(object.Text) else object.Text:SetTextColor(1,0.82,0) end
            elseif layout.kind=="radio" then
                local labelWidth=object.cfRadioLabelWidth or (full and 70 or 100)
                object.cfLabel:SetWidth(labelWidth); object:SetHitRectInsets(0,-labelWidth,0,0)
                if full then Ink(object.cfLabel) else object.cfLabel:SetTextColor(1,0.82,0) end
            end
        end
        for _,line in ipairs(f.optionDividers) do SetVisible(line,not full) end
        SetVisible(bindings.footerLine,not full)
        for _,page in pairs(f.pages) do
            Place(page,full and LEFT or 20,full and TOP or 114,full and 710 or 720,full and 250 or 440)
        end
        for i,page in ipairs(f.optionPages) do
            local tab=f.tabs[page.id]
            if not tab.cfBaseBackdrop then tab.cfBaseBackdrop=tab:GetBackdrop() end
            if not tab.cfBookHover then
                local enter=tab:GetScript("OnEnter")
                tab:SetScript("OnEnter",function(self)
                    if enter then enter(self) end
                    if f.cfGrimoire then self.cfLabel:SetTextColor(1,0.96,0.72) end
                end)
                tab.cfBookHover=true
            end
            tab:SetFrameLevel(f:GetFrameLevel()+60)
            if full then
                Place(tab,1110,383+(i-1)*63.5,156,48); tab:SetBackdrop(nil)
                tab.cfLabel:SetWidth(108); tab.cfLabel:SetFontObject("GameFontNormalSmall")
                tab.cfSelectedLine:SetSize(122,1)
            else
                Place(tab,20+(i-1)*182,62,174,32); tab:SetBackdrop(tab.cfBaseBackdrop)
                tab.cfLabel:SetWidth(158); tab.cfLabel:SetFontObject("GameFontNormal")
                tab.cfSelectedLine:SetSize(172,2); tab.cfSelectedLine:SetColorTexture(0.88,0.69,0.30,1)
            end
        end
        design:SetParent(full and f or f.pages.general)
        Place(design,full and 1095 or 0,full and 617 or 334,full and 190 or 720,full and 190 or 90)
        design:SetBackdrop(nil); SetVisible(designArt,full)
        designTitle:SetText(CF.T("OPTIONS_DESIGN"))
        designTitle:SetFontObject(full and "GameFontNormalSmall" or "GameFontNormal")
        designTitle:SetJustifyH(full and "CENTER" or "LEFT")
        designTitle:SetTextColor(0.88,0.78,0.56)
        Place(designTitle,full and 29 or 0,full and 65 or 0,full and 132 or 720,full and 19 or 24)
        for i,name in ipairs({"FULL","minimal"}) do
            local button=f.designChoices[name]
            button.cfBookDesign=full
            Place(button,full and 15.2 or ((i-1)*360),full and (i==1 and 93.1 or 137.75) or 34,full and 163.4 or 20,full and 35.15 or 20)
            for _,saved in ipairs(button.cfNativeRegions) do saved[1]:SetAlpha(full and 0 or saved[2]) end
            button.label:ClearAllPoints()
            if full then button.label:SetPoint("CENTER",button,"CENTER",13,0)
            else button.label:SetPoint("LEFT",button,"RIGHT",4,0) end
            button.label:SetWidth(full and 100 or 90)
            button:SetHitRectInsets(0,full and 0 or -90,0,0)
            SetVisible(button.bookFace,full)
            button.label:SetText(name=="FULL" and (CF.GetEffectiveLanguage()=="de" and "Voll" or "Full") or "Minimal")
            button:SetChecked(db.optionsDesign==name); button.CFRefreshLook(false)
        end
        designHelp:SetText(CF.T("OPTIONS_DESIGN_HELP")); Place(designHelp,0,68,720,34); SetVisible(designHelp,not full)
        f.optionLabels.OPTIONS_MINIMAP_HELP:Hide()
        if f.optionLabels.RAID_MANY_TEXT then f.optionLabels.RAID_MANY_TEXT:SetText(CF.T("RAID_MANY_TEXT")) end
        if full then
            -- Every page has two independent columns, one per parchment leaf.
            Label("OPTIONS_ACCESS",0,0); Label("OPTIONS_MAIN_WINDOW",RIGHT,0)
            Control("language",0,27,COLUMN,28); Control("minimap",0,61); Slider("radius",0,94)
            Slider("transparency",0,166)
            f.optionLabels.OPTIONS_MINIMAP_HELP:Hide()
            Control("lock",RIGHT,27,COLUMN/2); Control("header",RIGHT+COLUMN/2,27,COLUMN/2)
            Slider("scale",RIGHT,60); Slider("trackerWidth",RIGHT,112); Slider("trackerHeight",RIGHT,164)
            Control("resetScale",RIGHT,222,COLUMN,28); Control("resetPosition",0,222,COLUMN,28)
            Label("TARGET_DISPLAY",0,0)
            Control("view",0,27,COLUMN,56)
            Label("DISPLAY_HINT",0,84,COLUMN,26); Control("barsSpellNames",0,84)
            Control("outOfCombat",0,112)
            Control("hideOutOfCombat",0,140)
            f.optionLabels.CLASS_FILTER:Hide()
            Label("CLASS_FILTER_SUMMARY",0,168,COLUMN,24); Control("filters",0,194,COLUMN,28)
            Control("health",0,224,COLUMN,26)
            Control("execute",RIGHT,224,COLUMN,26)
            -- Keep the final display controls within the page body.
            Control("extraIcons",RIGHT,162,150,26)
            Control("hideFrame",RIGHT+160,162,150,26)
            Control("auraLayout",RIGHT,194,150,26)
            Control("experimental",RIGHT+160,194,150,26)
            Label("PRIORITY_MARKER",RIGHT,0); Label("OPTIONS_PRIORITY_HELP",RIGHT,24,COLUMN,24); Control("priority",RIGHT,50,COLUMN,26)
            Label("CURSE_WATCHER",RIGHT,78); Label("CURSE_SUMMARY",RIGHT,102,COLUMN,28); Control("curse",RIGHT,134,COLUMN,26)
            Label("OPTIONS_MONITOR",0,0); Label("PERFORMANCE_SUMMARY",0,26,COLUMN,46); Control("monitor",0,78,COLUMN,28)
            Label("CARDS_TITLE",RIGHT,0); Label("CARDS_SUMMARY",RIGHT,26,COLUMN,46); Control("cards",RIGHT,78,COLUMN,28)
            Label("OPTIONS_RECORDING",0,122); Control("recording",0,150); Slider("minimum",0,183)
            Label("PERFORMANCE_LAYOUT",RIGHT,122); Label("OPTIONS_LAYOUT_HELP",RIGHT,148,COLUMN,42); Control("layout",RIGHT,192,COLUMN,28)
            f.optionLabels.OPTIONS_ARCHIVE_HELP:Hide()
            Label("CONTROLS",0,0); Label("HELP_TEXT",0,26,COLUMN,92)
            Label("RAID_MANY",0,126); Label("RAID_MANY_TEXT",0,152,COLUMN,52)
            f.optionLabels.RAID_MANY_TEXT:SetText(CF.T("RAID_MANY_SHORT"))
            Control("contact",0,214,COLUMN,28)
            Label("OPTIONS_INFORMATION",RIGHT,0); Place(bindings.build,RIGHT,26,COLUMN,58)
            Control("history",RIGHT,91,COLUMN,26); Control("status",RIGHT,122,COLUMN,26); Label("OPTIONS_COMMANDS",RIGHT,157,COLUMN,65)
            f.optionLabels.OPTIONS_COMMANDS:SetText(CF.T("OPTIONS_COMMANDS"):gsub("^[^\n]*\n",""))
            f.optionLabels.OPTIONS_CREDITS:Hide()
            -- The invariant two-word addon title is printed into the parchment artwork.
            bindings.title:Hide()
            Place(bindings.version,1115,816,150,20); bindings.version:SetTextColor(0.86,0.77,0.56)
            f.optionLabels.OPTIONS_SAVED:Hide()
            f.closeButton:ClearAllPoints(); f.closeButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-64,-342)
        else
            bindings.title:Show(); bindings.title:SetFontObject("GameFontNormalLarge"); bindings.title:SetJustifyH("LEFT")
            bindings.title:SetText("|cffdfbd62"..(CF.Client and CF.Client.title or "Cursive Forever").."|r  |cffd8d1c2"..CF.T("OPTIONS").."|r")
            f.closeButton:ClearAllPoints(); f.closeButton:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4)
        end
        for _,key in ipairs({"radius","scale","trackerWidth","trackerHeight","minimum","transparency","veilOpacity"}) do
            if f.controls[key] then SkinSlider(f.controls[key],full) end
        end
        f.controls.view.CFRefresh()
        if CF.LayoutOptionsPages then CF.LayoutOptionsPages(f,bindings) end
        bindings.applyDecoration(); f.CFRefreshTabs(); f.CFFitToScreen()
        if CF.MinimalOptions then CF.MinimalOptions.Apply(f,bindings) end
    end
    f.CFSetDesign=function(value)
        db.optionsDesign=value=="minimal" and "minimal" or "FULL"
        f.CFRefreshPresentation()
    end
end

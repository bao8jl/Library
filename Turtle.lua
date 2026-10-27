local Library = {}

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Connections = {}
local RainbowObjects = {}
local RainbowConnection
local ActiveDrag
local OpenPopup
local Keybind
local Destroyed = false
local WindowCount = 0

local TextColor = Color3.fromRGB(245, 246, 250)
local MutedColor = Color3.fromRGB(220, 221, 225)
local BorderColor = Color3.fromRGB(113, 128, 147)
local ControlColor = Color3.fromRGB(53, 59, 72)
local BackgroundColor = Color3.fromRGB(47, 54, 64)
local AccentColor = Color3.fromRGB(0, 168, 255)
local PopupIndex = 100000

local function Create(ClassName, Properties)
	local Object = Instance.new(ClassName)

	if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
		Object.Font = Enum.Font.SourceSans
		Object.TextSize = 16
		Object.TextColor3 = TextColor
		Object.Text = ""
	end

	for Property, Value in Properties do
		if Property == "Parent" then continue end

		Object[Property] = Value
	end

	Object.Parent = Properties.Parent
	return Object
end

local GuiParent = CoreGui

if gethui then
	GuiParent = gethui()
elseif PROTOSMASHER_LOADED and get_hidden_gui then
	GuiParent = get_hidden_gui()
end

local PreviousGui = GuiParent:FindFirstChild("TurtleUiLib")
if PreviousGui then PreviousGui:Destroy() end

if GuiParent ~= CoreGui then
	PreviousGui = CoreGui:FindFirstChild("TurtleUiLib")
	if PreviousGui then PreviousGui:Destroy() end
end

local TurtleUiLib = Create("ScreenGui", {
	Name = "TurtleUiLib",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Global,
})

if syn and syn.protect_gui then
	syn.protect_gui(TurtleUiLib)
end

TurtleUiLib.Parent = GuiParent

local function ClosePopup()
	if not OpenPopup then return end

	if ActiveDrag and ActiveDrag.Target:IsDescendantOf(OpenPopup.Frame) then
		ActiveDrag = nil
	end

	OpenPopup.Frame.Visible = false
	if OpenPopup.Arrow then OpenPopup.Arrow.Rotation = 0 end

	OpenPopup = nil
end

local function TogglePopup(Popup)
	local Visible = not Popup.Frame.Visible
	ClosePopup()

	if not Visible then return end

	OpenPopup = Popup
	Popup.Frame.Visible = true
	if Popup.Arrow then Popup.Arrow.Rotation = 180 end
end

local function StopDrag(Commit)
	local Drag = ActiveDrag
	ActiveDrag = nil

	if Commit and Drag and Drag.Finish then
		Drag.Finish()
	end
end

local function BindDrag(Target, Begin)
	Target.Active = true

	Target.InputBegan:Connect(function(Input)
		if Destroyed or ActiveDrag then return end
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end

		local Update, Finish = Begin(Input)
		if not Update then return end

		ActiveDrag = {
			Target = Target,
			Input = Input,
			Update = Update,
			Finish = Finish,
		}

		Update(Input.Position)
	end)

	Target.Destroying:Connect(function()
		if ActiveDrag and ActiveDrag.Target == Target then
			StopDrag(false)
		end
	end)
end

local function SetRainbow(Object, Update)
	if Update then
		RainbowObjects[Object] = {Update = Update, Busy = false}
	else
		RainbowObjects[Object] = nil
	end

	if not next(RainbowObjects) then
		if RainbowConnection then
			RainbowConnection:Disconnect()
			RainbowConnection = nil
		end
		return
	end

	if RainbowConnection then return end

	RainbowConnection = RunService.Heartbeat:Connect(function()
		local Color = Color3.fromHSV(os.clock() % 5 / 5, 1, 1)

		for Target, Entry in RainbowObjects do
			if Destroyed then break end
			if not Target.Parent or RainbowObjects[Target] ~= Entry or Entry.Busy then continue end

			Entry.Busy = true
			local Success, Error = pcall(Entry.Update, Color)
			Entry.Busy = false

			if not Success then warn("TurtleUI: " .. tostring(Error)) end
		end
	end)
end

local function Cleanup()
	if Destroyed then return end

	Destroyed = true
	ActiveDrag = nil
	OpenPopup = nil
	Keybind = nil

	for Index, Connection in Connections do
		Connection:Disconnect()
	end

	if RainbowConnection then
		RainbowConnection:Disconnect()
		RainbowConnection = nil
	end

	table.clear(Connections)
	table.clear(RainbowObjects)
end

TurtleUiLib.Destroying:Connect(Cleanup)

function Library:Destroy()
	if Destroyed then return end

	Cleanup()
	TurtleUiLib:Destroy()
end

function Library:Hide()
	if Destroyed then return end

	ClosePopup()
	StopDrag(false)
	TurtleUiLib.Enabled = not TurtleUiLib.Enabled
end

function Library:Keybind(Key)
	Keybind = type(Key) == "string" and Enum.KeyCode[Key] or Key
end

Connections[1] = UserInputService.InputChanged:Connect(function(Input)
	local Drag = ActiveDrag
	if not Drag then return end

	if not Drag.Target.Parent or not TurtleUiLib.Enabled then
		StopDrag(false)
		return
	end

	if Input == Drag.Input or (Drag.Input.UserInputType == Enum.UserInputType.MouseButton1 and Input.UserInputType == Enum.UserInputType.MouseMovement) then
		Drag.Update(Input.Position)
	end
end)

Connections[2] = UserInputService.InputEnded:Connect(function(Input)
	if ActiveDrag and Input == ActiveDrag.Input then
		StopDrag(true)
	end
end)

Connections[3] = UserInputService.WindowFocusReleased:Connect(function()
	StopDrag(true)
end)

Connections[4] = UserInputService.InputBegan:Connect(function(Input, Processed)
	if not Processed and Keybind and Input.KeyCode == Keybind and not UserInputService:GetFocusedTextBox() then
		Library:Hide()
	end

	if not OpenPopup then return end
	if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end

	for Index, Object in {OpenPopup.Button, OpenPopup.Frame} do
		local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize

		if Input.Position.X >= Position.X and Input.Position.X <= Position.X + Size.X
			and Input.Position.Y >= Position.Y and Input.Position.Y <= Position.Y + Size.Y then
			return
		end
	end

	ClosePopup()
end)

function Library:Window(Name)
	if Destroyed then return end

	WindowCount = WindowCount + 1
	local ZIndex = WindowCount * 10
	local Height = 33
	local Offset = 10
	local PreviousSlider = false

	local UiWindow = Create("Frame", {
		Name = "UiWindow",
		BackgroundColor3 = Color3.fromRGB(0, 151, 230),
		BorderColor3 = Color3.fromRGB(0, 151, 230),
		Position = UDim2.fromOffset(20 + (WindowCount - 1) * 230, 20),
		Size = UDim2.fromOffset(207, 26),
		ZIndex = ZIndex + 4,
		Parent = TurtleUiLib,
	})

	local Header = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = AccentColor,
		BorderColor3 = AccentColor,
		Size = UDim2.fromOffset(207, 26),
		ZIndex = ZIndex + 5,
		Parent = UiWindow,
	})

	local HeaderText = Create("TextLabel", {
		Name = "HeaderText",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(183, 26),
		Text = Name or "Window",
		TextColor3 = BackgroundColor,
		TextSize = 17,
		ZIndex = ZIndex + 6,
		Parent = Header,
	})

	local Window = Create("Frame", {
		Name = "Window",
		BackgroundColor3 = BackgroundColor,
		BorderColor3 = BackgroundColor,
		Size = UDim2.fromOffset(207, Height),
		ZIndex = ZIndex + 1,
		Parent = Header,
	})

	local Minimise = Create("TextButton", {
		Name = "Minimise",
		BackgroundColor3 = AccentColor,
		BorderColor3 = AccentColor,
		Position = UDim2.fromOffset(185, 2),
		Size = UDim2.fromOffset(22, 22),
		Font = Enum.Font.SourceSansLight,
		Text = "_",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 20,
		ZIndex = ZIndex + 7,
		Parent = Header,
	})

	Minimise.Activated:Connect(function()
		ClosePopup()
		StopDrag(false)
		Window.Visible = not Window.Visible
		Minimise.Text = Window.Visible and "_" or "+"
	end)

	BindDrag(HeaderText, function(Input)
		ClosePopup()
		local Initial = Input.Position
		local Position = UiWindow.Position

		return function(Current)
			local Delta = Current - Initial
			UiWindow.Position = UDim2.new(Position.X.Scale, Position.X.Offset + Delta.X, Position.Y.Scale, Position.Y.Offset + Delta.Y)
		end
	end)

	local function AddRow(IsSlider)
		local Step = IsSlider and (PreviousSlider and 60 or 70) or 32
		Height = Height + Step
		Offset = Offset + Step
		PreviousSlider = IsSlider == true
		Window.Size = UDim2.fromOffset(207, Height + 10)

		return Offset
	end

	local Functions = {}

	function Functions:Button(Name, Callback)
		local Button = Create("TextButton", {
			Name = "Button",
			BackgroundColor3 = ControlColor,
			BorderColor3 = BorderColor,
			Position = UDim2.fromOffset(12, AddRow()),
			Size = UDim2.fromOffset(182, 26),
			Text = Name or "Button",
			TextWrapped = true,
			ZIndex = ZIndex + 2,
			Parent = Window,
		})

		if Callback then Button.Activated:Connect(Callback) end
	end

	function Functions:Label(Text, Color)
		local Label = Create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, AddRow()),
			Size = UDim2.fromOffset(206, 29),
			Text = Text or "Label",
			TextColor3 = typeof(Color) == "Color3" and Color or MutedColor,
			ZIndex = ZIndex + 2,
			Parent = Window,
		})

		if Color == true then
			SetRainbow(Label, function(Value)
				Label.TextColor3 = Value
			end)

			Label.Destroying:Connect(function()
				SetRainbow(Label)
			end)
		end

		return Label
	end

	function Functions:Toggle(Text, On, Callback)
		local ToggleDescription = Create("TextLabel", {
			Name = "ToggleDescription",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, AddRow()),
			Size = UDim2.fromOffset(131, 26),
			Text = Text or "Toggle",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = ZIndex + 2,
			Parent = Window,
		})

		local ToggleButton = Create("TextButton", {
			Name = "ToggleButton",
			BackgroundColor3 = BackgroundColor,
			BorderColor3 = BorderColor,
			Position = UDim2.fromOffset(158, 2),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = ZIndex + 2,
			Parent = ToggleDescription,
		})

		local ToggleFiller = Create("Frame", {
			Name = "ToggleFiller",
			BackgroundColor3 = Color3.fromRGB(68, 189, 50),
			BorderColor3 = BackgroundColor,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.fromOffset(12, 12),
			Visible = On == true,
			ZIndex = ZIndex + 3,
			Parent = ToggleButton,
		})

		ToggleButton.Activated:Connect(function()
			ToggleFiller.Visible = not ToggleFiller.Visible
			if Callback then Callback(ToggleFiller.Visible) end
		end)

		local ToggleFunctions = {Destroying = ToggleButton.Destroying}

		function ToggleFunctions:SetValue(Value)
			ToggleFiller.Visible = Value == true
		end

		return ToggleFunctions
	end

	function Functions:Box(Text, Callback)
		local TextBox = Create("TextBox", {
			Name = "TextBox",
			BackgroundColor3 = ControlColor,
			BorderColor3 = BorderColor,
			Position = UDim2.fromOffset(99, AddRow()),
			Size = UDim2.fromOffset(95, 26),
			PlaceholderColor3 = MutedColor,
			PlaceholderText = "...",
			ClearTextOnFocus = false,
			ZIndex = ZIndex + 2,
			Parent = Window,
		})

		Create("TextLabel", {
			Name = "BoxDescription",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-85, 0),
			Size = UDim2.fromOffset(75, 26),
			Text = Text or "Box",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = ZIndex + 2,
			Parent = TextBox,
		})

		if not Callback then return end

		TextBox.FocusLost:Connect(function()
			Callback(TextBox.Text)
		end)
	end

	function Functions:Slider(Text, Min, Max, Default, Callback)
		Min, Max = Min or 1, Max or 100
		if Min > Max then Min, Max = Max, Min end

		Default = math.clamp(Default or (Min + Max) / 2, Min, Max)
		local Value = Default
		local Range = Max - Min

		local Slider = Create("Frame", {
			Name = "Slider",
			BackgroundColor3 = BackgroundColor,
			BorderColor3 = BorderColor,
			Position = UDim2.fromOffset(13, AddRow(true)),
			Size = UDim2.fromOffset(180, 6),
			ZIndex = ZIndex + 2,
			Parent = Window,
		})

		Create("TextLabel", {
			Name = "Description",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-10, -35),
			Size = UDim2.fromOffset(200, 21),
			Text = Text or "Slider",
			ZIndex = ZIndex + 2,
			Parent = Slider,
		})

		local SliderFiller = Create("Frame", {
			Name = "SilderFiller",
			BackgroundColor3 = Color3.fromRGB(76, 209, 55),
			BorderColor3 = BackgroundColor,
			BorderMode = Enum.BorderMode.Inset,
			ZIndex = ZIndex + 2,
			Parent = Slider,
		})

		local SliderButton = Create("Frame", {
			Name = "SliderButton",
			BackgroundColor3 = ControlColor,
			BorderColor3 = BorderColor,
			Size = UDim2.fromOffset(6, 22),
			ZIndex = ZIndex + 3,
			Parent = Slider,
		})

		local Current = Create("TextLabel", {
			Name = "Current",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(3, 22),
			Size = UDim2.fromOffset(0, 18),
			TextColor3 = MutedColor,
			TextSize = 14,
			ZIndex = ZIndex + 3,
			Parent = SliderButton,
		})

		Create("TextLabel", {
			Name = "Min",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-1, -44),
			Size = UDim2.fromOffset(77, 50),
			Text = tostring(Min),
			TextColor3 = MutedColor,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = ZIndex + 2,
			Parent = Slider,
		})

		Create("TextLabel", {
			Name = "Max",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(104, -44),
			Size = UDim2.fromOffset(77, 50),
			Text = tostring(Max),
			TextColor3 = MutedColor,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = ZIndex + 2,
			Parent = Slider,
		})

		local function SetValue(NewValue)
			Value = math.clamp(NewValue, Min, Max)
			local Alpha = Range == 0 and 0 or (Value - Min) / Range
			local X = (Slider.Size.X.Offset - SliderButton.Size.X.Offset) * Alpha

			SliderButton.Position = UDim2.fromOffset(X, -8)
			SliderFiller.Size = UDim2.fromOffset(X, 6)
			Current.Text = tostring(math.round(Value))
		end

		local function BeginSlider()
			return function(Position)
				local Width = Slider.AbsoluteSize.X - SliderButton.AbsoluteSize.X
				local Alpha = Width > 0 and math.clamp((Position.X - Slider.AbsolutePosition.X - SliderButton.AbsoluteSize.X / 2) / Width, 0, 1) or 0

				SetValue(math.clamp(math.round(Min + Range * Alpha), Min, Max))
			end, function()
				if Callback then Callback(Value) end
			end
		end

		BindDrag(Slider, BeginSlider)
		BindDrag(SliderButton, BeginSlider)
		SetValue(Default)

		local SliderFunctions = {}

		function SliderFunctions:SetValue(NewValue)
			SetValue(NewValue)
		end

		return SliderFunctions
	end

	function Functions:Dropdown(Text, Buttons, Callback, Selective)
		Text = tostring(Text or "Dropdown")
		local Items = {}

		local Dropdown = Create("TextButton", {
			Name = "Dropdown",
			BackgroundColor3 = ControlColor,
			BorderColor3 = BorderColor,
			Position = UDim2.fromOffset(12, AddRow()),
			Size = UDim2.fromOffset(182, 26),
			Text = Text,
			TextWrapped = true,
			ZIndex = ZIndex + 3,
			Parent = Window,
		})

		local DownSign = Create("TextLabel", {
			Name = "DownSign",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(155, 2),
			Size = UDim2.fromOffset(27, 22),
			Text = "^",
			TextColor3 = MutedColor,
			TextSize = 20,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			ZIndex = ZIndex + 4,
			Parent = Dropdown,
		})

		local DropdownFrame = Create("ScrollingFrame", {
			Name = "DropdownFrame",
			Active = true,
			BackgroundColor3 = ControlColor,
			BorderColor3 = ControlColor,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.fromOffset(182, 0),
			Visible = false,
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollBarThickness = 4,
			VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarImageColor3 = MutedColor,
			ZIndex = PopupIndex,
			Parent = Dropdown,
		})

		local Popup = {Button = Dropdown, Frame = DropdownFrame, Arrow = DownSign}

		Dropdown.Activated:Connect(function()
			TogglePopup(Popup)
		end)

		Dropdown.Destroying:Connect(function()
			if OpenPopup == Popup then ClosePopup() end
		end)

		local function Refresh(Reposition)
			if Reposition then
				for Index, Item in Items do
					Item.Position = UDim2.fromOffset(6, (Index - 1) * 27 + 1)
				end
			end

			DropdownFrame.CanvasSize = UDim2.fromOffset(0, #Items * 27 + 1)
			DropdownFrame.Size = UDim2.fromOffset(182, math.min(#Items, 7) * 27)
		end

		local DropdownFunctions = {}

		function DropdownFunctions:Button(Name)
			Name = Name or ""

			local Button = Create("TextButton", {
				Name = "Button",
				BackgroundColor3 = ControlColor,
				BorderColor3 = BorderColor,
				Position = UDim2.fromOffset(6, #Items * 27 + 1),
				Size = UDim2.fromOffset(170, 26),
				Text = tostring(Name),
				TextWrapped = true,
				ZIndex = PopupIndex + 1,
				Parent = DropdownFrame,
			})

			Items[#Items + 1] = Button
			Button.Activated:Connect(function()
				ClosePopup()
				if Selective then Dropdown.Text = tostring(Name) end
				if Callback then Callback(Name) end
			end)

			Refresh()
		end

		function DropdownFunctions:Remove(Name)
			for Index, Item in Items do
				if Item.Text ~= tostring(Name) then continue end

				table.remove(Items, Index)
				Item:Destroy()
				if Selective and Dropdown.Text == tostring(Name) then Dropdown.Text = Text end

				Refresh(true)
				return
			end

			warn("The button you tried to remove didn't exist!")
		end

		for Index, Name in Buttons or {} do
			DropdownFunctions:Button(Name)
		end

		return DropdownFunctions
	end

	function Functions:ColorPicker(Name, Default, Callback)
		local DefaultColor = typeof(Default) == "Color3" and Default or AccentColor
		local Hue, Saturation, Brightness = DefaultColor:ToHSV()

		local ColorPicker = Create("TextButton", {
			Name = "ColorPicker",
			BackgroundColor3 = DefaultColor,
			Position = UDim2.fromOffset(137, AddRow()),
			Size = UDim2.fromOffset(57, 26),
			ZIndex = ZIndex + 2,
			Parent = Window,
		})

		Create("UICorner", {
			Name = "PickerCorner",
			CornerRadius = UDim.new(0, 2),
			Parent = ColorPicker,
		})

		Create("TextLabel", {
			Name = "PickerDescription",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-123, 0),
			Size = UDim2.fromOffset(116, 26),
			Text = Name or "Color picker",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = ZIndex + 2,
			Parent = ColorPicker,
		})

		local ColorPickerFrame = Create("Frame", {
			Name = "ColorPickerFrame",
			BackgroundColor3 = BackgroundColor,
			BorderColor3 = BackgroundColor,
			Position = UDim2.fromOffset(80, -74),
			Size = UDim2.fromOffset(158, 155),
			Visible = false,
			ZIndex = PopupIndex,
			Parent = ColorPicker,
		})

		local Popup = {Button = ColorPicker, Frame = ColorPickerFrame}

		ColorPicker.Activated:Connect(function()
			TogglePopup(Popup)
		end)

		local ClosePicker = Create("TextButton", {
			Name = "ClosePicker",
			BackgroundColor3 = BackgroundColor,
			BorderColor3 = BackgroundColor,
			Position = UDim2.fromOffset(132, 5),
			Size = UDim2.fromOffset(21, 21),
			Text = "X",
			TextSize = 18,
			ZIndex = PopupIndex + 1,
			Parent = ColorPickerFrame,
		})

		ClosePicker.Activated:Connect(ClosePopup)

		Create("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.fromOffset(118, 21),
			Text = Name or "Color picker",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = PopupIndex + 1,
			Parent = ColorPickerFrame,
		})

		local ToggleRGB = Create("TextButton", {
			Name = "ToggleRGB",
			BackgroundColor3 = BackgroundColor,
			BorderColor3 = BorderColor,
			Position = UDim2.fromOffset(125, 127),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = PopupIndex + 1,
			Parent = ColorPickerFrame,
		})

		local ToggleFiller = Create("Frame", {
			Name = "ToggleFiller",
			BackgroundColor3 = Color3.fromRGB(76, 209, 55),
			BorderColor3 = BackgroundColor,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.fromOffset(12, 12),
			Visible = false,
			ZIndex = PopupIndex + 2,
			Parent = ToggleRGB,
		})

		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-113, 0),
			Size = UDim2.fromOffset(106, 22),
			Text = "Rainbow",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = PopupIndex + 1,
			Parent = ToggleRGB,
		})

		local Canvas = Create("Frame", {
			Name = "Canvas",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(5, 34),
			Size = UDim2.fromOffset(148, 64),
			ZIndex = PopupIndex + 1,
			Parent = ColorPickerFrame,
		})

		local CanvasGradient = Create("UIGradient", {
			Name = "CanvasGradient",
			Parent = Canvas,
		})

		Create("UICorner", {
			CornerRadius = UDim.new(0, 2),
			Parent = Canvas,
		})

		Create("ImageLabel", {
			Name = "BlackOverlay",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = "rbxassetid://5107152095",
			ZIndex = PopupIndex + 2,
			Parent = Canvas,
		})

		local Cursor = Create("ImageLabel", {
			Name = "Cursor",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(8, 8),
			Image = "rbxassetid://5100115962",
			ZIndex = PopupIndex + 3,
			Parent = Canvas,
		})

		local Color = Create("Frame", {
			Name = "Color",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(5, 105),
			Size = UDim2.fromOffset(148, 14),
			BorderMode = Enum.BorderMode.Inset,
			ZIndex = PopupIndex + 1,
			Parent = ColorPickerFrame,
		})

		Create("UIGradient", {
			Name = "ColorGradient",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.82, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
			Parent = Color,
		})

		Create("UICorner", {
			Name = "ColorCorner",
			CornerRadius = UDim.new(0, 2),
			Parent = Color,
		})

		local ColorSlider = Create("Frame", {
			Name = "ColorSlider",
			BackgroundColor3 = MutedColor,
			BorderColor3 = MutedColor,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(2, 14),
			ZIndex = PopupIndex + 2,
			Parent = Color,
		})

		local function UpdateColor(Notify, Rainbow)
			local Value = Color3.fromHSV(Hue, Saturation, Brightness)
			ColorPicker.BackgroundColor3 = Value
			CanvasGradient.Color = ColorSequence.new(Color3.fromHSV(Hue, 1, 1), Color3.new(1, 1, 1))
			Cursor.Position = UDim2.new(1 - Saturation, -4, 1 - Brightness, -4)
			ColorSlider.Position = UDim2.fromScale(Hue, 0)

			if Notify and Callback then Callback(Value, Rainbow) end
		end

		local function SetRainbowEnabled(Enabled)
			if Enabled == ToggleFiller.Visible then return end

			ToggleFiller.Visible = Enabled

			if not Enabled then
				SetRainbow(ColorPicker)
				return
			end

			SetRainbow(ColorPicker, function(Value)
				Hue, Saturation, Brightness = Value:ToHSV()
				UpdateColor(true, true)
			end)
		end

		ToggleRGB.Activated:Connect(function()
			SetRainbowEnabled(not ToggleFiller.Visible)
		end)

		BindDrag(Canvas, function()
			SetRainbowEnabled(false)

			return function(Position)
				local Origin, Size = Canvas.AbsolutePosition, Canvas.AbsoluteSize
				Saturation = 1 - math.clamp((Position.X - Origin.X) / Size.X, 0, 1)
				Brightness = 1 - math.clamp((Position.Y - Origin.Y) / Size.Y, 0, 1)
				UpdateColor(true)
			end
		end)

		BindDrag(Color, function()
			SetRainbowEnabled(false)

			return function(Position)
				Hue = math.clamp((Position.X - Color.AbsolutePosition.X) / Color.AbsoluteSize.X, 0, 1)
				UpdateColor(true)
			end
		end)

		ColorPicker.Destroying:Connect(function()
			SetRainbow(ColorPicker)
			if OpenPopup == Popup then ClosePopup() end
		end)

		UpdateColor(false)
		if Default == true then SetRainbowEnabled(true) end

		local ColorFunctions = {}

		function ColorFunctions:UpdateColorPicker(Value)
			if typeof(Value) == "Color3" then
				SetRainbowEnabled(false)
				Hue, Saturation, Brightness = Value:ToHSV()
				UpdateColor(false)
			elseif type(Value) == "boolean" then
				SetRainbowEnabled(Value)
			end
		end

		return ColorFunctions
	end

	return Functions
end

return Library

-- A utility to simplify connecting a Discord Webhook to Roblox.

-- Services
local HttpService = game:GetService("HttpService")

-- A running value to track if the script is currently executing or not
local runningValue = nil
if not script:WaitForChild("running") then 
	runningValue = Instance.new("BoolValue")
	runningValue.Parent = script
	runningValue.Name = "running"
else
	runningValue = script:WaitForChild("running")
end

-- Type definition for a single field in an embed
export type field = {
	name : string,      -- The name of the field
	value : string,     -- The value/content of the field
	inline : boolean    -- Whether the field is inline in the embed (default is false)
}

export type fieldImpl = {
	name : string,      -- The name of the field
	value : string,     -- The value/content of the field
	inline : boolean?    -- Whether the field is inline in the embed (default is false)
}

-- Type definition for the embed data structure
export type embedData = {
	Title : string,           -- The title of the embed
	AuthorName : string,      -- The author of the embed
	IconUrl : string,         -- The URL of the icon image for the author
	Description : string,     -- The description/content of the embed
	Color : number,           -- The color of the embed (hex code as string)
	Footer : string?,         -- Optional footer text (defaults to "Powered by Roblox" if not provided)
	Fields : {fieldImpl}      -- A list of fields to include in the embed
}

export type embedDataImpl = {
	Title : string?,           -- The title of the embed
	AuthorName : string?,      -- The author of the embed
	IconUrl : string?,         -- The URL of the icon image for the author
	Description : string,     -- The description/content of the embed
	Color : number?,           -- The color of the embed (hex code as string)
	Footer : string?,         -- Optional footer text (defaults to "Powered by Roblox" if not provided)
	Fields : {fieldImpl}?      -- A list of fields to include in the embed
}

export type RbxToDiscordImpl = {
	Colors: {[string] : number},
	new: (webhookUrl: string, EmbedData: embedData?) -> RbxToDiscordImpl,
	sendEmbed: (EmbedData: embedData?) -> RbxToDiscordImpl,
	createField: (options: fieldImpl) -> field,
	customColor: (Color: Color3 | string) -> number,
	createEmbedData: (options: embedDataImpl) -> embedData,
	_url: string,
	_payload: embedDataImpl,
	_payloadDelay: number,
	_running: BoolValue,
	_color: string?
}


-- Initialize the RbxToDiscord table for functions and properties
local RbxToDiscord = {}
RbxToDiscord.__index = RbxToDiscord

-- A table of predefined colors for the embed

-- Creates a field to be included in the embed
-- @param Name: The name of the field
-- @param Value: The value of the field
-- @param Inline: Whether the field is inline (optional, defaults to false)
-- @return: A table representing the field
function RbxToDiscord:createField(options : fieldImpl) : field
	return {
		name = options.name,
		value = options.value,
		inline = options.inline or false
	} :: field
end

-- Converts a Color3 object or a string to a numerical hex value (e.g., 0x3498db)
-- @param Color: Can be either a Color3 object or a hex color string
-- @return: A numerical hex value representing the color (e.g., 0x3498db)
function RbxToDiscord:customColor(Color : Color3 | string) : number?
	-- If the input is a string (hex code), convert it to a numerical value
	if type(Color) == "string" then
		-- Ensure the string starts with '#' and remove it before converting
		if Color:sub(1, 1) == "#" then
			Color = Color:sub(2)
		end

		-- Convert the hex string to a number
		return tonumber(Color, 16)
	end

	-- If the input is a Color3 object, convert it to a numerical hex value
	local r = math.floor(Color.R * 255)
	local g = math.floor(Color.G * 255)
	local b = math.floor(Color.B * 255)

	-- Return the combined hex value as a number (e.g., 0x3498db)
	return (r * 0x10000) + (g * 0x100) + b
end

-- Creates the data for the embed, including all necessary fields
-- @param Title: The title of the embed
-- @param AuthorName: The name of the author
-- @param IconUrl: The URL for the author's icon
-- @param Description: The description/content of the embed
-- @param Fields: A list of fields to include in the embed (optional)
-- @param Footer: The footer text (optional, defaults to empty)
-- @return: A table representing the embed data
function RbxToDiscord:createEmbedData(options : embedDataImpl) : embedData
	if not options.Color then
		 options.Color = 0x3498db
	end
	print(options)
	return options :: embedData
end

-- Creates a new webhook handler with an optional embed payload
-- @param webhookUrl: The Discord webhook URL
-- @param embedData: Optional embed data to be sent with the webhook
-- @return: An instance of RbxToDiscord ready to send webhooks
function RbxToDiscord.new(webhookUrl : string, EmbedData : embedData?)
	local self = setmetatable({}, RbxToDiscord)

	self._url = webhookUrl
	self._payload = EmbedData
	self._payloadDelay = 5   -- Delay before sending another message (default 5 seconds)
	self._running = runningValue
	self._color = 0x3498db   -- Default color for the embed
	self.Colors = {
		Red = 0xFF0000,
		Green = 0x00FF00,
		Blue = 0x0000FF,
		Yellow = 0xFFFF00,
		Orange = 0xFFA500,
		Purple = 0x800080,
		Pink = 0xFFC0CB,
		Cyan = 0x00FFFF,
		Black = 0x000000,
		White = 0xFFFFFF,
		Gray = 0x808080,
		LightGray = 0xD3D3D3,
		DarkGray = 0xA9A9A9,
		LightBlue = 0xADD8E6,
		DarkBlue = 0x00008B,
		Lime = 0x00FF00,
		Teal = 0x008080,
		Brown = 0xA52A2A,
		Gold = 0xFFD700,
		Coral = 0xFF7F50,
		MidnightBlue = 0x191970,
		ForestGreen = 0x228B22,
		SlateBlue = 0x6A5ACD,
		Indigo = 0x4B0082,
		LightPink = 0xFFB6C1,
		DarkRed = 0x8B0000,
		Violet = 0xEE82EE,
		LightGreen = 0x90EE90,}

	return self
end

-- Sets the delay between sending webhooks (the server-wide delay)
-- @param delayTime: The delay time in seconds
-- @return: The RbxToDiscord instance for chaining
function RbxToDiscord:setDelay(delayTime : number)
	self._payloadDelay = delayTime
	return self
end

-- Connects a new webhook URL to override the previous one
-- @param webhookUrl: The new Discord webhook URL
-- @return: The RbxToDiscord instance for chaining
function RbxToDiscord:connectWebhook(webhookUrl : string)
	self._url = webhookUrl
	return self
end

-- Sends the embed to the Discord webhook
-- @param EmbedData: The embed data to send (optional)
-- @return: The RbxToDiscord instance for chaining
function RbxToDiscord:sendEmbed(EmbedData : embedData?)
	if self._running.Value == true then return end
	self._running.Value = true

	-- Save the current payload to restore after sending
	local cache = self._payload
	if EmbedData then
		self._payload = EmbedData
	end
	print(self._payload)
	if not self._payload.Fields then
		self._payload.Fields = {} 
	end
	if not self._payload.Footer then
		self._payload.Footer = "Powered by Roblox" 
	end

	local embed = {
		embeds = {
			{
				title = self._payload.Title or "",
				description = self._payload.Description,
				color = self._payload.Color,
				author = {
					name = self._payload.AuthorName or "",
					icon_url = self._payload.IconUrl or ""
				},
				fields = self._payload.Fields or {},
				footer = {
					text = self._payload.Footer or ""
				}
			}
		}
	}

	-- Restore the previous payload
	self._payload = cache

	-- Convert the embed table to JSON format
	local payload = HttpService:JSONEncode(embed)

	-- Send the HTTP POST request to the Discord Webhook
	local postSuccess, errorMessage = pcall(function()
		HttpService:PostAsync(self._url, payload, Enum.HttpContentType.ApplicationJson)
	end)

	if not postSuccess then
		warn("Failed to send webhook: " .. errorMessage)
	else
		print("Embed sent successfully!")
	end

	-- Wait for the specified delay before allowing another webhook to be sent
	task.spawn(function()
		task.wait(self._payloadDelay)
		self._running.Value = false
	end)

	return self
end
-- Return the RbxToDiscord module
return RbxToDiscord

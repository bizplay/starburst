Starburst::Engine.routes.draw do
	post "announcements/:id/mark_as_read", to: "announcements#mark_as_read", as: "mark_as_read"
	get "announcements/recent", to: "announcements#recent"
end

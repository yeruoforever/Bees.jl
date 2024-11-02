module Role

"the role of the message."
@enum RoleType begin
    system
    user
    assistant
    tool
end
export RoleType

end

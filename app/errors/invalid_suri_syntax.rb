# frozen_string_literal: true

##
# this allows us to re-raise certain StandardErrors from moab-versioning in a more
# specifically rescue-able way
class InvalidSuriSyntax < StandardError
end

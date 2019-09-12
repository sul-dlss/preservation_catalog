# frozen_string_literal: true

##
# this allows us to re-raise certain StandardErrors from moab-versioning in a more
# specifically rescue-able way
# TODO: move into moab-versioning gem, and remove this class once https://github.com/sul-dlss/moab-versioning/issues/159
# is implemented
class InvalidSuriSyntax < StandardError
end

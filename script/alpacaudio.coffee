# -*- coding: utf-8 -*-
# vim: set ts=2 sts=2 sw=2 :
#
###! Copyright (C) 2014, 2015 Mark Lee, under the GPL (version 3+) ###
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

do ($ = jQuery) ->
  $.fn.replaceClass = (to_remove, to_add) ->
    ###
    For a given jQuery object, replace one or more classes with another set of
    one or more classes.
    ###
    return this.removeClass(to_remove).addClass(to_add)

# namespace
AlpacAudio = {}

# Used for storage identifiers
AlpacAudio.player_name = 'AlpacAudio'

AlpacAudio.base_template_url = '/templates'

AlpacAudio.QUEUE_ID = 'queue'

AlpacAudio.get_template = (id, variable_name = 'model') ->
  ###
  Shortcut for creating a template function.

  Retrieves the template data by selecting the contents of an element by ID,
  and sets the name of the top-level variable in the template.
  If the template does not exist in the DOM, attempt to retrieve it via XHR.

  :rtype: :js:class:`Function`
  ###
  return (callback) ->
    template_dom_id = "##{id}-tpl"
    template_element = $(template_dom_id)
    make_template = (template_str) ->
      return _.template(template_str, null, { variable: variable_name })
    if template_element.length > 0
      callback(make_template(template_element.html()))
    else
      template_url = "#{AlpacAudio.base_template_url}/#{id}.mtpl"
      $.get(template_url).done (template_str) ->
        $('body').append($('<script type="text/template"/>').
                  attr(id: template_dom_id).text(template_str))
        callback(make_template(template_str))

AlpacAudio.song_url = (metadata) ->
  ###
  Generates a song URL based on song metadata.

  :type metadata: :js:class:`Object` with ``id`` key
  :rtype: :js:class:`String`
  ###
  return "/songs/#{metadata.id}"

AlpacAudio.notify = (title, options) ->
  return unless notify.isSupported
  permission_level = notify.permissionLevel()
  switch permission_level
    when notify.PERMISSION_DEFAULT
      notify.requestPermission (result) ->
        AlpacAudio.notify(title, options) if result is notify.PERMISSION_GRANTED
    when notify.PERMISSION_GRANTED
      options ||= {}
      options.icon = '/favicon.ico' unless options.icon?
      notify.createNotification(title, options)
    # do nothing for notify.PERMISSION_DENIED

class AlpacAudio.View extends Backbone.View
  ###
  Abstract base class for common AlpacAudio+Backbone views.
  ###
  render: ->
    ###
    Renders a template using the data from
    :meth:`~init::AlpacAudio.View.render_data`, and puts it in the
    view's element.

    :return: The view being operated on, for chaining purposes.
    :rtype: :class:`init::AlpacAudio.View`
    ###
    @template (template) =>
      @$el.html(template(@render_data()))
    return this

  render_data: ->
    ###
    The data used by the view to render the template.

    :rtype: :js:class:`Object`
    ###
    return @model.toJSON()

class AlpacAudio.SingletonView extends AlpacAudio.View
  ###
  Abstract base class for singleton views.
  ###
  replace: (relative_selector, manip_func) ->
    ###
    Removes the existing view and replaces it with the currently rendered one.

    :param relative_selector: The CSS selector that is used to create a jQuery
                              object that serves as a reference point to attach
                              the view to the document.
    :param manip_func: The jQuery DOM manipulation function that is used to
                       attach the view to the document, relative to the jQuery
                       object created via ``relative_selector``.
    ###
    $("##{@id}").remove()
    $(relative_selector)[manip_func](@el)
    @delegateEvents()
  renderify: (relative_selector, manip_func) ->
    ###
    Removes the existing view and replaces it with the newly rendered one.

    :param relative_selector: The CSS selector that is used to create a jQuery
                              object that serves as a reference point to attach
                              the view to the document.
    :param manip_func: The jQuery DOM manipulation function that is used to
                       attach the view to the document, relative to the jQuery
                       object created via ``relative_selector``.
    ###
    @render()
    @replace(relative_selector, manip_func)

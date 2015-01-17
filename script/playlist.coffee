# -*- coding: utf-8 -*-
# vim: set ts=2 sts=2 sw=2 :
#
###! Copyright (C) 2014 Mark Lee, under the GPL (version 3+) ###
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

####
# Models / Collections
####

class AlpacAudio.Playlist extends Backbone.Model
  ###
  A representation of a Google Music playlist.
  ###
  constructor: (data, options) ->
    data ||= {}
    tracks = if data.tracks? then data.tracks else []
    data.tracks = new AlpacAudio.PlaylistEntries(tracks)
    super(data, options)

  add_track: (track) ->
    ###
    Appends a track to a playlist.

    :type track: :class:`AlpacAudio.Track`
    ###
    @add_entries(new AlpacAudio.PlaylistEntry({track: track}))

  add_entries: (entry_or_entries) ->
    ###
    Appends one or more playlist entries to a playlist.

    :type entry_or_entries: :class:`AlpacAudio.PlaylistEntry` or an :js:class:`Array`
                            of :class:`AlpacAudio.PlaylistEntry` objects.
    ###
    @get('tracks').add(entry_or_entries)

class AlpacAudio.PlaylistCollection extends Backbone.Collection
  model: AlpacAudio.Playlist
  url: '/playlists'
  parse: (resp) ->
    ###
    Prunes playlist entries sans metadata, and playlists without any
    playable entries.
    ###
    return resp.playlists.filter (playlist) ->
      playlist.tracks = playlist.tracks.filter (entry) ->
        return entry.track?.storeId?
      return playlist.tracks.length > 0

class AlpacAudio.PlaylistEntry extends Backbone.Model
  constructor: (data, options) ->
    track = data.track
    data.track = new AlpacAudio.Track(track)
    super(data, options)

class AlpacAudio.PlaylistEntries extends Backbone.Collection
  model: AlpacAudio.PlaylistEntry

class AlpacAudio.Track extends Backbone.Model
  constructor: (data, options) ->
    data.id = data.storeId if !!data && !!data.storeId
    super(data, options)

class AlpacAudio.Tracks extends Backbone.Collection
  model: AlpacAudio.Track

####
# Views
####

class AlpacAudio.PlaylistView extends AlpacAudio.SingletonView
  tagName: 'section'
  id: 'playlist'
  template: AlpacAudio.get_template('playlist', 'playlist')
  track_template: AlpacAudio.get_template('playlist-track', 'pt')
  events:
    'mouseover .albumart span.fa': 'album_mouseover'
    'mouseout .albumart span.fa': 'album_mouseout'
    'click .albumart span.fa-play': 'play_track'
    'click .add-to-queue': 'add_to_queue'

  constructor: (options) ->
    super(options)
    tracks = @model.get('tracks')
    tracks.on('add', @on_tracks_add)

  render_track: (playlist_entry, idx) =>
    data = playlist_entry.toJSON()
    data.idx = idx if idx?
    return @track_template(data)

  render_data: ->
    data = super()
    data.render_track = @render_track
    return data

  ####
  # Event handlers
  ####

  album_mouseover: (e) ->
    icon = $(e.target)
    return false if icon.hasClass('fa-music') or icon.hasClass('fa-spinner')
    icon.addClass('fa-play')

  album_mouseout: (e) ->
    icon = $(e.target)
    return false if icon.hasClass('fa-music') or icon.hasClass('fa-spinner')
    icon.removeClass('fa-play')

  _play_track: (song, icon) ->
    spin_cls = 'fa-spinner fa-spin'
    @$('.albumart span.fa-music').removeClass('fa-music')
    @$('.albumart span.fa-spinner').removeClass(spin_cls)
    @current_icon = icon
    AlpacAudio.player.play(song)
    icon.replaceClass('fa-play', spin_cls)
    unless @_set_play_started_handler?
      AlpacAudio.player.audio.play_started =>
        @current_icon.replaceClass(spin_cls, 'fa-music') if @current_icon
      @_set_play_started_handler = true
    AlpacAudio.player.audio.error =>
      @current_icon.removeClass(spin_cls) if @current_icon
      @current_icon = null

  play_track: (e) ->
    icon = $(e.target)
    entry_id = icon.closest('tr').data('entry-id')
    entry = @model.get('tracks').get(entry_id)
    queue = AlpacAudio.queue.model
    queue.insert_entry_after_current(entry)
    unless AlpacAudio.player.is_playing()
      last = queue.get('tracks').length - 1
      if queue.get('current_track') == last
        queue.trigger('change:current_track', queue, last)
      else
        queue.set('current_track', last)

  add_to_queue: ->
    AlpacAudio.queue.model.add_playlist(@model)
    AlpacAudio.notify("Added playlist '#{@model.get('name')}' to queue.")

  on_tracks_add: (model, collection, options) =>
    track = @render_track(model, collection.indexOf(model))
    if options.at? # insert
      @$el.find("tbody tr:nth-child(#{options.at})").before(track)
    else # append
      @$el.find('tbody').append(track)

class AlpacAudio.PlaylistEntryView extends AlpacAudio.View
  tagName: 'li'
  template: AlpacAudio.get_template('playlist-entry', 'entry')

####
# Routers
####

class AlpacAudio.PlaylistRouter extends Backbone.Router
  routes:
    'playlist/:id': 'load_playlist'

  constructor: (options) ->
    super(options)
    @playlists =
      queue: AlpacAudio.queue.render()

  load_playlist: (id) ->
    view = @playlists[id]
    func = 'replace'
    unless view
      view = new AlpacAudio.PlaylistView({
        model: AlpacAudio.playlists.get(id)
      })
      @playlists[id] = view
      func = 'renderify'
    view[func]('main nav:first', 'after')

# -*- coding: utf-8 -*-
# vim: set ts=2 sts=2 sw=2 :
#
###! Copyright (C) 2014, 2015, 2016, 2017 Mark Lee, under the GPL (version 3+) ###
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

class AlpacAudio.Chromecast
  ###
  Uses chrome.cast to play MP3s.
  ###
  constructor: ->
    @session = null
    APP_ID = chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID
    CAPABILITIES = [chrome.cast.Capability.AUDIO_OUT]
    session_request = new chrome.cast.SessionRequest(APP_ID, CAPABILITIES)
    api_config = new chrome.cast.ApiConfig(session_request,
                                           @on_session_event,
                                           @on_receiver_event)
    chrome.cast.initialize(api_config, @on_cast_success, @on_cast_error)

  on_session_event: (session) -> console.log('Session Listener', session)
  on_cast_success: ->
  on_receiver_event: (receiver_availability) =>
    if receiver_availability is chrome.cast.ReceiverAvailability.AVAILABLE
      chrome.cast.requestSession(@on_session_success, @on_session_error)

  on_cast_error: (error) ->
    console.error('Cast Error', error)

  on_session_success: (session) ->
    @session = session

    # create_evt_func = (name, args...) ->
    #   return (handler) ->
    #     if handler?
    #       @$player.on name, handler
    #     else if !!@player[name]
    #       @player[name](args...)
    #     else
    #       @$player.trigger(name, args)
    # for n in ['play', 'pause', 'timeupdate', 'ended', 'error']
    #   @[n] = create_evt_func(n)

    # create_prop_func = (name) ->
    #   return (val = null) ->
    #     if val is null
    #       return @player[name]
    #     else
    #       @player[name] = val
    # for n in ['currentTime', 'volume']
    #   @[n] = create_prop_func(n)

    # @playing = false
    # @$player.on 'play', =>
    #   @playing = true
    # @$player.on 'pause', =>
    #   @playing = false

  load: (url) ->
    return unless @session

    media_info = new chrome.cast.media.MediaInfo(url, AlpacAudio.MP3_FMT)
    load_request = new chrome.cast.media.LoadRequest
    load_request.autoplay = true
    @session.loadMedia(load_request, @on_load_success, @on_load_error)

  on_load_success: (media) ->
    console.log('LOADED')
    @media = media
    @play_started_handler()

  on_load_error: (error) ->
    console.error('LOAD ERROR', error)

  currentTime: (val = null) ->
    track = @current_track()
    return unless track
    if val is null
      return track.getEstimatedTime()
    else
      @seek_to(track, val)

  audio_playable: ->
    window.chrome && window.chrome.cast

  mp3_playable: -> true

  supports_command: (track, command) ->
    track or= @current_track()

    track?.supportsCommand(chrome.cast.media.MediaCommand[command])

  pauseable: (track) ->
    @supports_command(track, 'PAUSE')

  play_started: (handler) ->
    if handler?
      @play_started_handler = handler
    else
      @is_playing()

  # toggle_playback: ->
  #   if @playing
  #     @player.pause()
  #   else
  #     @player.play()

  seekable: (track) ->
    @supports_command(track, 'SEEK')

  seek: (delta) ->
    track = @current_track()
    return unless track
    @seek_to(track, track.getEstimatedTime() + delta)

  seek_to: (track, position) ->
    return unless @seekable(track)

    request = new chrome.cast.media.SeekRequest()
    request.currentTime = position
    track.seek(request, @on_seek_success, @on_seek_error)

  on_seek_success: ->
  on_seek_error: (error) ->
    console.error('Seek error', error)

  stop: ->
    track = @current_track()
    return unless track

    track.stop(new chrome.cast.media.StopRequest(),
               @on_stop_success,
               @on_stop_error)

  on_stop_success: ->
  on_stop_error: (error) ->
    console.error('Stop error', error)

  current_track: ->
    return null unless @session

    @session.media.find (media_item) ->
      media_item.playerState is chrome.cast.media.PlayerState.PLAYING

  is_playing: ->
    @current_track()?

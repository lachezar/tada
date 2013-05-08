class Task extends Backbone.Model
  defaults: () ->
    {
      title: "...",
      next_id: null,
      done: false
    }

  toggle: () ->
    @save({done: not @get("done")})


class TaskList extends Backbone.Collection

  model: Task,
    
  url: '/api/task'

  # fix flask restless collection json structure
  parse: (response) ->
    return response.objects
    
  done: () ->
    @where({done: true})

  # Filter down the list to only todo items that are still not finished.
  remaining: () ->
    @without.apply(@, @done())

  # next_id is pointing to the following task in the linkd list,
  # so technically we are not sorting by this.
  comparator: 'next_id'


class TaskView extends Backbone.View

  tagName:  "li"

  template: Mustache.compile($("#task-template").html())

  events: {
    "click .toggle": "toggleDone",
    "click .title": "edit",
    "keypress .edit": "updateOnEnter",
    "blur .edit": "close"
  }

  initialize: () ->
    @listenTo @model, 'change', @render
    @listenTo @model, 'change:id', @changeAndSort
    @listenTo @model, 'destroy', @removeAndSort

  render: () ->
    @$el.html @template(@model.toJSON())
    @$el.toggleClass('done', @model.get('done'))
    @input = @$('.edit')
    @
    
  changeAndSort: () ->
    @el.dataset.id = @model.id # set data-id to the li element
    App.vent.trigger('sort')
    
  removeAndSort: () ->
    @remove()
    App.vent.trigger('sort')
    
  toggleDone: () ->
    @model.toggle()

  edit: () ->
    @$el.addClass('editing')
    @input.focus()

  close: () ->
    newTitle = @input.val()
      
    if newTitle  
      if newTitle != @model.get('title')
        @model.save {title: newTitle}
          
      @$el.removeClass('editing')
    else
      @clear()

  updateOnEnter: (e) ->
    @close() if e.keyCode == 13 

  clear: () ->
    @model.destroy()


class AppView extends Backbone.View

  el: $(".container")
    
  events: {
    "keypress #new-todo": "createNewTask",
    "click .add-button": "createNewTask",
    "click #complete-all-checkbox": "completeAllTasks"
  }
    
  # handle event between the views
  vent: _.extend({}, Backbone.Events)

  initialize: () ->
    
    @tasks = new TaskList

    @input = @$("#new-todo")
    @completeAll = @$("#complete-all")
    @remaining = @$("#complete-all .remaining")

    @listenTo @tasks, 'add', @addOne
    @listenTo @tasks, 'reset', @addAll
    @listenTo @tasks, 'all', @render

    @footer = @$('footer')
    @main = @$('#main')

    # since all tasks' html is served by the server,
    # load from an embedded JSON structure.
    @tasks.reset(preloadedTasks)
      
    # make the list sortable, except the "complete all" element
    @$("#task-list").sortable(
      {
        handle: ".draggable", 
        stop: @sort, 
        cursor: 'move',
        items: ">li[data-id]"
      }
    )
    @$("#task-list").disableSelection()
      
    # whoever triggers sort event will sort the tasks
    @vent.on('sort', @sort, @)

  # Re-rendering the App just means refreshing the statistics -- the rest
  # of the app doesn't change.
  render: () ->
    remaining = @tasks.remaining().length
      
    if remaining > 1
      @remaining.html remaining
      @completeAll.show()
    else
      @completeAll.hide()

  # Add a single todo item to the list by creating a view for it, and
  # appending its element to the `<ul>`.
  addOne: (task) ->
    view = new TaskView({model: task})
    @$("#task-list").append(view.render().el)
    # handle the task to mark all completed
    @completeAll.insertAfter("#task-list li:last")
    # must execute sortable 'refresh' with delay, 
    # but jQuery delay does not work for us
    setTimeout( 
      () =>
        @$("#task-list").sortable('refresh')
      , 500)
    
  # Add preloaded task without rendering
  addPreloaded: (task) ->
    view = new TaskView({model: task, el: @$("li[data-id=#{task.id}]")})
    view.input = @$("li[data-id=#{task.id}] .edit")

  # Add all items in the tasks collection at once.
  addAll: () ->
    @tasks.each @.addPreloaded, @

  # If you hit return in the main input field, create new Task
  createNewTask: (e) ->
    return if (e.keyCode >= 0 and e.keyCode != 13) or not @input.val()

    @tasks.create({title: @input.val()})
    @input.val('')
    
  completeAllTasks: () ->
    $.ajax('/api/task/complete-all', {type: 'PATCH'})
      .then(
        () => 
          @$("#complete-all :checkbox").removeAttr('checked')
          @tasks.each (task) -> task.set({'done': true})
    )
    
  # After the ordering event is completed by jQuery
  # it is our turn to send the patch of the linked list to the server.
  # It should take up to 3 requests at most - one for the moved task,
  # one for the previous task of the old position and one for the
  # previous task on the new postion on which the task was moved.
  sort: () =>
    ids = $("#task-list").sortable('toArray', {'attribute': 'data-id'})

    prevTask = @tasks.get(ids[0])
    for id in ids.slice(1)
      if prevTask.get('next_id') != +id # +id to make it int
        prevTask.save({'next_id': id})
      prevTask = @tasks.get(id)
        
    if prevTask and prevTask.get('next_id') != null
      # last element points to null
      prevTask.save({'next_id': null})

App = new AppView


$(() ->
  Task = Backbone.Model.extend(
    defaults: () ->
      {
        title: "empty todo...",
        order: Todos.nextOrder(),
        done: false
      }

    toggle: () ->
      @save({done: not @get("done")})
    ,
  
    #url: '/api/task/[id]'
  )

  TodoList = Backbone.Collection.extend(

    # Reference to this collection's model.
    model: Task,
    
    url: '/api/task',

    # Save all of the todo items under the `"todos-backbone"` namespace.
    #localStorage: new Backbone.LocalStorage("todos-backbone"),
    # add backend
    
    # fix flask restless collection json structure
    parse: (response) ->
      return response.objects
    ,
    
    done: () ->
      @where({done: true})
    ,

    # Filter down the list to only todo items that are still not finished.
    remaining: () ->
      @without.apply(@, @done());
    ,

    nextOrder: () ->
      @length
    ,

    # Todos are sorted by their original insertion order.
    comparator: 'order'

  )

  Todos = new TodoList

  TodoView = Backbone.View.extend(

    tagName:  "li",

    template: Mustache.compile($('#task-template').html()),

    events: {
      "click .toggle": "toggleDone",
      "click .title": "edit",
      "click a.destroy": "clear",
      "keypress .edit": "updateOnEnter",
      "blur .edit": "close"
    },

    initialize: () ->
      @listenTo @model, 'change', @render
      @listenTo @model, 'destroy', @remove

    render: () ->
      @$el.html @template(@model.toJSON())
      @$el.toggleClass 'done', @model.get('done')
      @el.dataset.id = @model.id # set data-id to the li element
      @input = @$('.edit')
      @
    ,
    
    toggleDone: () ->
      @model.toggle()
    ,

    edit: () ->
      @$el.addClass "editing"
      @input.focus()
    ,

    close: () ->
      value = @input.val()
      if value
        @model.save {title: value}
        @$el.removeClass "editing"
      else
        @clear()
    ,

    updateOnEnter: (e) ->
      @close() if e.keyCode == 13 
    ,

    clear: () ->
      @model.destroy()

  )

  AppView = Backbone.View.extend(

    el: $(".container"),
    
    # Our template for the line of statistics at the bottom of the app.
    remainingTemplate: Mustache.compile($('#remaining-template').html()),

    events: {
      "keypress #new-todo": "createNewTask",
      "click .add-button": "createNewTask",
      "click #clear-completed": "clearCompleted",
      "click #toggle-all": "toggleAllComplete"
    },

    # At initialization we bind to the relevant events on the `Todos`
    # collection, when items are added or changed. Kick things off by
    # loading any preexisting todos that might be saved in *localStorage*.
    initialize: () ->

      @input = @$("#new-todo")
      @allCheckbox = @$("#toggle-all")[0]

      @listenTo Todos, 'add', @addOne
      @listenTo Todos, 'reset', @addAll
      #@listenTo Todos, 'all', @render

      @footer = @$('footer')
      @main = @$('#main')

      #Todos.fetch() 
      Todos.reset(preloadedTasks)
      #Todos.each App.addOne, App
      
      $("#task-list").sortable({handle: ".draggable", stop: @sort});
      $("#task-list").disableSelection();
    ,

    # Re-rendering the App just means refreshing the statistics -- the rest
    # of the app doesn't change.
    ###render: () ->
      done = Todos.done().length
      remaining = Todos.remaining().length

      if Todos.length
        @main.show()
        @footer.show()
        @footer.html @remainingTemplate({done: done, remaining: remaining})
      else
        @main.hide()
        @footer.hide()

      #@allCheckbox.checked = not remaining
    ,###

    # Add a single todo item to the list by creating a view for it, and
    # appending its element to the `<ul>`.
    addOne: (task) ->
      view = new TodoView({model: task})
      @$("#task-list")
        .append(view.render().el)
        .sortable('refresh')
    ,
    
    addPreloaded: (task) ->
      view = new TodoView({model: task, el: @$("li[data-id=#{task.id}]")})
      view.input = @$("li[data-id=#{task.id}] .edit")
    ,

    # Add all items in the **Todos** collection at once.
    addAll: () ->
      Todos.each @.addPreloaded, @
    ,

    # If you hit return in the main input field, create new **Todo** model,
    # persisting it to *localStorage*.
    createNewTask: (e) ->
      return if (e.keyCode and e.keyCode != 13) or not @input.val()

      Todos.create({title: @input.val()})
      @input.val('')
    ,
    
    # Clear all done todo items, destroying their models.
    clearCompleted: () -> #not needed
      _.invoke Todos.done(), 'destroy'
      false
    ,

    toggleAllComplete: () ->
      done = @allCheckbox.checked
      Todos.each (task) -> task.save({'done': done})
    ,
    
    sort: (event, ui) ->
      $("#task-list li").map(
        (i, e) ->
          id = e.dataset.id
          task = Todos.get(id)
          if task.get('order') != i
            task.save({'order': i})
      )
    ,
  

  )

  App = new AppView
)

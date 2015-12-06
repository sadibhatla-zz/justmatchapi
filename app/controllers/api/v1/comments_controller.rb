class Api::V1::CommentsController < Api::V1::BaseController
  # NOTE: All API documentation for this Controller exists in users/comments_controller

  resource_description { api_versions '1.0' }

  def index
    @comments = @commentable.comments

    render json: @comments
  end

  def show
    render json: @comment
  end

  def create
    @comment = @commentable.comments.new(comment_params)
    @comment.owner_user_id = current_user.id

    if @comment.save
      render json: @comment, status: :created
    else
      render json: @comment.errors, status: :unprocessable_entity
    end
  end

  def update
    @comment = current_user.written_comments.find(params[:id])
    @comment.body = comment_params[:body]

    if @comment.save
      render json: @comment, status: :ok
    else
      render json: @comment.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @comment = current_user.written_comments.find(params[:id])
    @comment.destroy

    head :no_content
  end

  private

    def comment_params
      params.require(:comment).permit(:body)
    end
end
